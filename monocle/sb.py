from time import time
from asyncio import Semaphore

from .db import Session
from .shared import get_logger, SessionManager, LOOP
from . import sanitized as conf

log = get_logger("sb-detector")

class SbAccountException(Exception):
    """Raised when an account is shadow banned"""

class SbDetector:
        
    detect_semaphore = Semaphore(4, loop=LOOP)

    def __init__(self):
        self.ran_at = {}

        self.session = Session(autocommit=True)
        if conf.SB_WEBHOOK:
            from .notification import Notifier
            self.notifier = Notifier()
        else:
            self.notifier = None
        log.info("SbDetector initialized.")

    async def detect(self, username):
        async with self.detect_semaphore:
            await self.detect_concurrent(username)

    async def detect_concurrent(self, username):
        if username in self.ran_at:
            ran_at = self.ran_at[username]
        else:
            ran_at = 0

        if time() - ran_at < conf.SB_COOLDOWN:
            return
        
        log.info("Detecting sb for {}", username)

        self.ran_at[username] = time()

        query = """
        SELECT username,
            COUNT(*) sightings,
            SUM(uncommon) AS uncommon
            FROM (
                SELECT username,
                CASE WHEN (pokemon_id IN :non_sb_pokemon_ids) THEN 0  ELSE 1 END AS uncommon,
                s.expire_timestamp
                FROM sighting_users su
                LEFT JOIN sightings s on s.id = su.sighting_id
                WHERE expire_timestamp > :min_expire_timestamp AND
                su.username = :username
        ) agg
        GROUP BY username
        """

        try:
            result = self.session.execute(query, {
                'username': username,
                'non_sb_pokemon_ids': conf.SB_UNCOMMON_POKEMON_IDS,
                'min_expire_timestamp': time() - conf.SB_QUARANTINE_SECONDS,
                }).first()

            if result:
                sightings = result[1]
                uncommon = int(result[2])
                sbanned = (sightings >= conf.SB_MIN_SIGHTING_COUNT and uncommon <= conf.SB_MAX_UNCOMMON_COUNT)

                log.info("Username: {}, sightings: {}, uncommon: {}, sbanned: {}",
                        result[0],
                        sightings,
                        uncommon,
                        sbanned)
        
                if sbanned:
                    if self.notifier:
                        await self.webhook(self.notifier, conf.SB_WEBHOOK, username)

                    raise SbAccountException()
        except SbAccountException as e:
            raise e
        except Exception as e:
            log.exception('A wild {} appeared!', e.__class__.__name__)

    async def webhook(self, notifier, endpoint, username):
        """ Send a notification via webhook
        """
        payload = {
            'type': 'sban',
            'message': {
                'username': username,
            }
        }

        session = SessionManager.get()
        return await notifier.hook_post(endpoint, session, payload)
