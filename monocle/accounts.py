import os
import enum
import csv
from time import time
from queue import Queue
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, UniqueConstraint, exists
from sqlalchemy.types import Integer, Boolean, Enum, SmallInteger, String
from . import db, utils, sanitized as conf
from .shared import LOOP, get_logger, run_threaded
            
instance_id = conf.INSTANCE_ID[-32:]

class Provider(enum.Enum):
    ptc = 1
    google = 2 


class MonocleDialect(csv.Dialect):
    delimiter=','
    quotechar='"'
    quoting=csv.QUOTE_MINIMAL
    lineterminator='\n'
    skipinitialspace=True


class GomanDialect(csv.Dialect):
    delimiter=':'
    quotechar='"'
    quoting=csv.QUOTE_MINIMAL
    lineterminator='\n'
    skipinitialspace=True


class Account(db.Base):
    __tablename__ = 'accounts'

    id = Column(Integer, primary_key=True)
    instance = Column(String(32), index=True, nullable=True)
    username = Column(String(32), nullable=False)
    password = Column(String(32), nullable=False)
    provider = Column(String(12), nullable=False)
    level = Column(SmallInteger, default=1, nullable=False, index=True)
    model = Column(String(20))
    device_version = Column(String(20))
    device_id = Column(String(64))
    hibernated = Column(Integer, index=True)
    reason = Column(String(12))
    captchaed = Column(Integer, index=True)
    created = Column(Integer, default=time)
    updated = Column(Integer, default=time, onupdate=time)
    
    __table_args__ = (
        UniqueConstraint(
            'username',
            name='ix_accounts_username_unique'
        ),
    )

    @staticmethod
    def to_account_dict(account):
        d = {
                'instance': account.instance,
                'internal_id': account.id,
                'username': account.username,
                'password': account.password,
                'provider': account.provider,
                'level': account.level,
                'model': account.model,
                'iOS': account.device_version,
                'id': account.device_id,
                'time': 0,
                }
        if account.captchaed:
            d['captcha'] = True
        if account.hibernated:
            if account.reason == 'sbanned':
                d['sbanned'] = True
            elif account.reason == 'warn':
                d['warn'] = True
            elif account.reason == 'banned':
                d['banned'] = True
        return d

    @staticmethod
    def from_account_dict(session, account_dict, account_db=None, assign_instance=True, update_flags=True):
        account = {}

        for k in account_dict:
            v = account_dict[k]
            if v is not None:
                account[k] = v

        username = account['username']
        if not account_db and 'internal_id' in account:
                account_db = session.query(Account) \
                        .filter(Account.id==account['internal_id']) \
                        .with_lockmode("update") \
                        .first()
        if not account_db:
            account_db = Account.lookup(session, username, lock=True)
        if not account_db:
            account_db = Account(username=username)

        if assign_instance:
            account_db.instance = instance_id
        if 'provider' in account:
            account_db.provider = account.get('provider')
        else:
            account_db.provider = 'ptc'

        if 'password' in account:
            account_db.password = account.get('password')
        if 'level' in account:
            account_db.level = account.get('level')
        if 'model' in account:
            account_db.model = account.get('model')
        if 'iOS' in account:
            account_db.device_version = account.get('iOS')
        if 'id' in account:
            account_db.device_id = account.get('id')

        if update_flags:
            if 'captcha' in account:
                account_db.captchaed = int(time())
            else:
                account_db.captchaed = None

            if 'banned' in account and account['banned']:
                account_db.hibernated = int(time())
                account_db.reason = 'sbanned'
            elif 'sbanned' in account and account['sbanned']:
                account_db.hibernated = int(time())
                account_db.reason = 'banned'
            elif 'warn' in account and account['warn']:
                account_db.hibernated = int(time())
                account_db.reason = 'warn'
            else:
                account_db.hibernated = None
                account_db.reason = None
        return account_db

    @staticmethod
    def query_builder(session, min_level, max_level):
        q = session.query(Account) \
                .filter(Account.instance==None,
                        Account.hibernated==None,
                        Account.captchaed==None)
        if min_level:
            q = q.filter(Account.level >= min_level)
        if max_level:
            q = q.filter(Account.level <= max_level)
        return q

    @staticmethod
    def has_more_sync(min_level, max_level):
        with db.session_scope() as session:
            q = Account.query_builder(session, min_level, max_level)
            return session.query(q.exists()).scalar()

    @staticmethod
    def get_sync(min_level, max_level):
        with db.session_scope() as session:
            q = Account.query_builder(session, min_level, max_level)
            account = q.with_lockmode("update").first()
            if account:
                account.instance = instance_id
                account_dict = Account.to_account_dict(account)
            else:
                account_dict = None
        return account_dict

    @staticmethod
    def put_sync(account_dict):
        with db.session_scope() as session:
            account = Account.from_account_dict(session, account_dict, assign_instance=True)
            session.merge(account)
            session.commit()
            account_dict['internal_id'] = account.id

    @staticmethod
    async def has_more(min_level,max_level):
        await run_threaded(Account.has_more_sync, min_level, max_level)

    @staticmethod
    async def get(min_level, max_level):
        return await run_threaded(Account.get_sync, min_level, max_level)

    @staticmethod
    async def put(account_dict):
        await run_threaded(Account.put_sync, account_dict)

    @staticmethod
    def lookup(session, username, lock=False):
        account_db = session.query(Account) \
                .filter(Account.username==username)
        if lock:
            account_db.with_lockmode("update")
        return account_db.first()


    @staticmethod
    def import_file(file_location, level=0, assign_instance=True):
        """
        Specify force_level to update level.
        Otherwise, it will be set to 0 when level info is not available in pickles. 
        Level will be automatically updated upon login.
        """
        pickled_accounts = load_accounts()

        with open(file_location, 'rt') as f:
            csv_reader = csv.reader(f)
            csv_headings = next(csv_reader)
            fieldnames = ['username','password','provider','model','iOS','id']
            if csv_headings == fieldnames:
                print("=> Input file recognized as Monocle accounts.csv format")
                fieldnames = None
                dialect = MonocleDialect
            else:
                print("=> Input file recognized as Goman format")
                dialect = GomanDialect

        with open(file_location, 'rt') as f:
            reader = csv.DictReader(f, fieldnames=fieldnames, dialect=dialect)
            with db.session_scope() as session:
                new_count = 0
                update_count = 0
                pickle_count = 0
                for row in reader:
                    username = row['username']
                    password = row['password'].strip().strip(',')

                    account_db = Account.lookup(session, username, lock=True)

                    if not account_db:
                        account_db = Account(username=username)
                        new_count += 1
                    else:
                        update_count += 1

                    if username in pickled_accounts:
                        pickled_account = pickled_accounts[username]
                        account = {k:pickled_account[k] for k in row}
                        account['password'] = password   # Allow password change
                        pickle_count += 1
                    elif account_db.id:
                        account = row
                    else:
                        account = utils.generate_device_info(row)
                        account['level'] = level

                    account_db = Account.from_account_dict(session,
                            account,
                            account_db=account_db,
                            assign_instance=assign_instance,
                            update_flags=False)
                    session.merge(account_db)

                print("=> {} new accounts inserted.".format(new_count))
                print("=> {} existing accounts in DB updated as ncessary.".format(update_count))
                print("=> {} accounts updated with data found in pickle.".format(pickle_count))


class AccountQueue(Queue):
    #def _init(self, maxsize):
    #    print("ACCOUNT QUEUE INIT")
    #    super()._init(maxsize)

    #def _qsize(self):
    #    print("ACCOUNT QUEUE QSIZE")
    #    size = super()._qsize()
    #    if size == 0:
    #        new_account = LOOP.run_until_complete(Account.get(0,29))
    #        self.queue.append(new_account)
    #        return super()._qsize()
    #    else:
    #        return size

    #def _get(self):
    #    print("ACCOUNT QUEUE _GET")
    #    return super()._get()

    def _put(self, item):
        print("ACCOUNT QUEUE PUT")
        LOOP.run_until_complete(Account.put(item))
        super()._put(item)

    #def put(self, item, block=True, timeout=None):
    #    super().put(item, block=block, timeout=timeout)
    #    print("ACCOUNT QUEUE PUT")

    def get(self, block=True, timeout=None):
        print("ACCOUNT QUEUE GET")
        if self.qsize() == 0:
            new_account = LOOP.run_until_complete(Account.get(0,29))
            self.queue.append(new_account)
            print("ACCOUNT QUEUE GET FROM DB")

        return super().get(block=block, timeout=timeout)


class CaptchaAccountQueue(Queue):
    def _init(self, maxsize):
        super()._init(maxsize)

    def _qsize(self):
        return super()._qsize()

    def _put(self, item):
        LOOP.run_until_complete(Account.put(item))
        super()._put(item)

    def _get(self):
        return super()._get()


def load_accounts():
    pickled_accounts = utils.load_pickle('accounts')

    if conf.ACCOUNTS_CSV:
        accounts = load_accounts_csv()
        if pickled_accounts and set(pickled_accounts) == set(accounts):
            return pickled_accounts
        else:
            accounts = accounts_from_csv(accounts, pickled_accounts)
    elif conf.ACCOUNTS:
        if pickled_accounts and set(pickled_accounts) == set(acc[0] for acc in conf.ACCOUNTS):
            return pickled_accounts
        else:
            accounts = accounts_from_config(pickled_accounts)
    else:
        raise ValueError('Must provide accounts in a CSV or your config file.')

    utils.dump_pickle('accounts', accounts)
    return accounts


def load_accounts_csv():
    csv_location = os.path.join(conf.DIRECTORY, conf.ACCOUNTS_CSV)
    with open(csv_location, 'rt') as f:
        accounts = {}
        reader = csv.DictReader(f)
        for row in reader:
            accounts[row['username']] = dict(row)
    return accounts

ACCOUNTS = load_accounts()
