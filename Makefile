EXTENSION = ddla
DATA = ddla--0.1.sql
PG_CONFIG = /usr/lib/postgresql/10/bin/pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

