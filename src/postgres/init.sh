#!/bin/bash
set -e

check_database_online() {
    PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1" >/dev/null 2>&1
}

consecutive_checks_required=2
consecutive_checks=0

while true; do
    if check_database_online; then
        consecutive_checks=$((consecutive_checks+1))
    else
        consecutive_checks=0
    fi

    if [ $consecutive_checks -ge $consecutive_checks_required ]; then
        echo "db is up"
        break
    fi

    echo "waiting for db..."
    sleep 5
done

AUTHELIA_DB="authelia"

PGPASSWORD=$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=1 -h $POSTGRES_HOST --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
        -- Check if the user exists
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_user WHERE usename = '$AUTHELIA_USER') THEN
            -- Create the user
            CREATE USER "$AUTHELIA_USER" WITH PASSWORD '$AUTHELIA_PASSWORD';
        END IF;
    END
    \$\$;
EOSQL

if ! PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -lqt | cut -d \| -f 1 | grep -qw "$AUTHELIA_DB"; then
    PGPASSWORD=$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=1 -h $POSTGRES_HOST -U $POSTGRES_USER -c "CREATE DATABASE $AUTHELIA_DB"
else
    echo "Database $AUTHELIA_DB already exists."
fi

# Grant privileges
PGPASSWORD=$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=1 -h $POSTGRES_HOST -U $POSTGRES_USER -c "GRANT ALL PRIVILEGES ON DATABASE $AUTHELIA_DB TO \"$AUTHELIA_USER\";"

PGPASSWORD=$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=1 -h $POSTGRES_HOST --username "$POSTGRES_USER" --dbname $AUTHELIA_DB <<-EOSQL
    GRANT ALL ON SCHEMA public TO "$AUTHELIA_USER";
EOSQL

echo "init finished"