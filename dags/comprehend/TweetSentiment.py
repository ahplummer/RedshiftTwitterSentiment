from tweepy import *
import json
import os
import boto3
from botocore.config import Config

import logging
logging.basicConfig(
    format="%(name)s-%(levelname)s-%(asctime)s-%(message)s", level=logging.INFO
)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


twitter_api_key = os.environ["TWITTER_API_KEY"]
twitter_api_key_secret = os.environ["TWITTER_API_KEY_SECRET"]
twitter_access_token = os.environ["TWITTER_ACCESS_TOKEN"]
twitter_access_token_secret = os.environ["TWITTER_ACCESS_TOKEN_SECRET"]
twitter_search = os.environ["TWITTER_SEARCH"]
twitter_count = os.environ["TWITTER_COUNT"]
aws_stream=os.environ["AWS_STREAM"]

my_config = Config(
    region_name = 'us-east-2',
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


def storeResults(uniondict):
    if not isinstance(uniondict, dict):
        print("type error goes here")
        return
    if "SentimentScore" not in uniondict['comprehendpayload']:
        print(uniondict)
        print("error goes here")
        return
    kclient = boto3.client('firehose')
    responseStr = json.dumps(uniondict)
    encodedValues = bytes(responseStr, 'utf-8')
    response = kclient.put_record(
        DeliveryStreamName=aws_stream,
        Record={'Data' : encodedValues}
    )
    print(uniondict)
    print(response)

def execComprehend(tweetpayload):
    uniondict = dict()
    client = boto3.client('comprehend', config=my_config)
    response = client.detect_sentiment(
        Text = tweetpayload['text'],
        LanguageCode="en"
    )
    uniondict['tweetpayload'] = tweetpayload
    uniondict['comprehendpayload'] = response
    storeResults(uniondict)

def execTwitter():
    logger.info('=====Executing exec method=====')
    auth = OAuthHandler(twitter_api_key, twitter_api_key_secret)
    auth.set_access_token(twitter_access_token, twitter_access_token_secret)
    api = API(auth, wait_on_rate_limit=True)
    search_words = twitter_search  # enter your words
    new_search = search_words + " -filter:retweets"
    for tweet in Cursor(api.search,q=new_search,
                               lang="en",
                               since_id=0).items(int(twitter_count)):
        print("Scoring, and storing: " + str(tweet.text))
        execComprehend(tweet._json)

if __name__ == "__main__":
    logger.info('=====Executing Comprehend Driver=====')
    execTwitter()


