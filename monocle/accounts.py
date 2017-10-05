import enum
from time import time
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, UniqueConstraint
from sqlalchemy.types import Integer, Boolean, Enum, SmallInteger, String
#Column, Boolean, Integer, String, Float, SmallInteger, BigInteger, ForeignKey, Index, UniqueConstraint, create_engine, cast, func, desc, asc, desc, and_, exists
from . import db

class Provider(enum.Enum):
    ptc = 1
    google = 2 

class Account(db.Base):
    __tablename__ = 'accounts'

    id = Column(Integer, primary_key=True)
    instance = Column(String(32), index=True, nullable=False)
    username = Column(String(32), nullable=False)
    password = Column(String(32), nullable=False)
    provider = Column(String(12), nullable=False)
    level = Column(SmallInteger, default=1, nullable=False, index=True)
    model = Column(String(20))
    device_version = Column(String(20))
    device_id = Column(String(64))
    ban_reason = Column(String(12))
    banned = Column(Integer, index=True)
    created = Column(Integer,default=time)
    updated = Column(Integer,default=time,onupdate=time)
    

    __table_args__ = (
        UniqueConstraint(
            'username',
            name='ix_accounts_username_unique'
        ),
    )
