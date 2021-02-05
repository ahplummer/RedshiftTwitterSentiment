
## Description
* This starts up three containers:
    * Airflow Website
    * Airflow Scheduler
    * Postgres
* This spins up DBT, and leverages Redshift, Kinesis, and S3

### Features
* Twitter Comprehend DAG:  Runs every 5 minutes, 24 hours a day.
  * Task 1
    * Connects to Twitter API, downloads x tweets with given search criteria, 
    * Gets Sentiment analysis via AWS Comprehend.  
    * This then uploads the tweet and sentiment data to AWS Kinesis Firehose. The Firehose drops the files into S3, and attempts to store into Redshift.
  * Task 2
    * Executes DBT transform task that massages and extracts data from JSON payload (from RAW table), and inserts into STORE table.

* Redshift Error Catchup - in the event that Redshift is paused, this task is designed to "catch up" Redshift from the S3 errors in inserting from Kinesis Firehose. Runs once a day at 7:30 AM Central. 
  * Task 1
    * Connects to Redshift via Postgres connection, connects to S3, and processes the files in S3 marked "error", and moves those files to "error-processed".
  
## Prerequisites:
1. AWS admin rights, newest AWS CLI installed
2. Terraform installed

## Infrastructure deployment
NOTE: This should be all worked from the ./infra directory.
See [Readme.md in infra](./infra/Readme.md)
* Outcomes:
  * Redshift with table configured, pause/resume schedule, and role
  * S3 configured
  * Kinesis Firehose configured

## Running
* Setup .env file in main project directory (this is different than the infra version of the .env):
```
AIRFLOW__CORE__LOAD_DEFAULT_CONNECTIONS=False
AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgres+psycopg2://airflow:airflow@postgres:5432/airflow
#Do the following in the command prompt:
#execute python
#>>> from cryptography.fernet import Fernet
#>>> fernet_key= Fernet.generate_key()
#>>> print(fernet_key.decode()) # your fernet_key
#>>> quit()
AIRFLOW__CORE__FERNET_KEY=<fernet_key output from above>
AIRFLOW_CONN_METADATA_DB=postgres+psycopg2://airflow:airflow@postgres:5432/airflow
AIRFLOW_VAR__METADATA_DB_SCHEMA=airflow
AIRFLOW__SCHEDULER__SCHEDULER_HEARTBEAT_SEC=10
AWS_ACCESS_KEY_ID=<your aws key> 
AWS_SECRET_ACCESS_KEY=<your aws secret>
AWS_STREAM=<what you used to setup infra>
AWS_DEFAULT_REGION=<what you used to setup infra>
AWS_S3_BUCKET=<what you used to setup S3>
TWITTER_API_KEY=<see Twitter docs> 
TWITTER_API_KEY_SECRET=<see Twitter docs> 
TWITTER_ACCESS_TOKEN=<see Twitter docs> 
TWITTER_ACCESS_TOKEN_SECRET=<see Twitter docs> 
TWITTER_SEARCH=<criteria>
TWITTER_COUNT=<number per run>
DBT_SERVER=<the actual endpoint created>
DBT_USER=<what you used to setup Redshift>
DBT_PASSWORD=<what you used to setup Redshift>
DBT_DATABASE=<what you used to setup Redshift>
```
* Via Docker: 
```
docker-compose up -d --remove-orphans --build
```

* Open browser: http://127.0.0.1:8080

* Login with admin/password, and peek at the DAGs

* Login to the AWS console for Redshift and explore the data.


### Sources
* [This post from 8/6/2020](https://blog.knoldus.com/running-apache-airflow-dag-with-docker/)