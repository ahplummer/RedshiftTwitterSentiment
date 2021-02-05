from tweepy import *
import os
import boto3
from botocore.config import Config
import psycopg2

import logging
logging.basicConfig(
    format="%(name)s-%(levelname)s-%(asctime)s-%(message)s", level=logging.INFO
)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

aws_s3_bucket=os.environ["AWS_S3_BUCKET"]
aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"]
aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"]
dbt_server = os.environ["DBT_SERVER"]
dbt_user = os.environ["DBT_USER"]
dbt_password = os.environ["DBT_PASSWORD"]
dbt_database = os.environ["DBT_DATABASE"]

my_config = Config(
    region_name = 'us-east-1',
    signature_version = 'v4',
    retries = {
        'max_attempts': 10,
        'mode': 'standard'
    }
)
# This is the redshift `create table` DDL.
# create table raw_sentiment
# 	(id INT IDENTITY(1,1),
#      loaded_at datetime default sysdate,
#      comprehendpayload varchar(65535),
#      tweetpayload varchar(65535)
#     );

def execProcessErrors():
    basecommand = '''COPY raw_sentiment (comprehendpayload,tweetpayload) FROM '{0}' CREDENTIALS 'aws_access_key_id={1};aws_secret_access_key={2}' MANIFEST json 'auto';'''
    s3 = boto3.resource('s3')
    conn_string = "postgresql://{}:{}@{}:{}/{}".format(
        dbt_user,
        dbt_password,
        dbt_server,
        5439,
        dbt_database
    )
    conn = psycopg2.connect(conn_string)
    bucket = s3.Bucket(aws_s3_bucket)
    for obj in bucket.objects.filter(Prefix = "errors/manifests/"):
        # process each manifest...
        s3address = "s3://" + aws_s3_bucket + "/" + obj.key
        command = basecommand.format(s3address, aws_access_key_id, aws_secret_access_key)
        print("Performing COPY from S3 to Redshift for " + obj.key)
        with conn.cursor() as curs:
            curs.execute(command)
        conn.commit()
        print("Done...")
        newkey = obj.key.replace("errors", "errors-processed")
        print('Changing key from {} to {}'.format(obj.key, newkey))
        s3.Object(aws_s3_bucket, newkey).copy_from(CopySource=aws_s3_bucket + "/" + obj.key)
        s3.Object(aws_s3_bucket, obj.key).delete()
    conn.close()


if __name__ == "__main__":
    logger.info('=====Executing ErrorCatchup Driver=====')
    execProcessErrors()

