#!/usr/bin/env bash
#airflow upgradedb
airflow db init
airflow users create \
    --username admin \
    --lastname lastname \
    --firstname firstname \
    --role Admin \
    --email admin@example.org \
    --password password
airflow webserver