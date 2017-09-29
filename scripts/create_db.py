#!/usr/bin/env python3

import sys, os

print('')
print('DEPRECATION WARNING: script/create_db.py is deprecated in Monocle/Monkey.')
print('Run `{}/alembic upgrade head` instead.'.format(os.path.dirname(sys.executable)))
print('')
