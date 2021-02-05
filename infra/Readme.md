# Instructions for Redshift

## Create .env file, and source it: `source .env`
```
#!/bin/bash
export TF_VAR_REDSHIFT_NAME=""
export TF_VAR_DB_NAME=""
export TF_VAR_DB_RAW_TABLE=""
export TF_VAR_REDSHIFT_USER=""
export TF_VAR_REDSHIFT_PASSWORD=""
export TF_VAR_REGION=""
export TF_VAR_VPC_AZ=""
#openssl rand -hex 10
export TF_VAR_BUCKET_NAME=""
export TF_VAR_BUCKET_KEY=""
export TF_VAR_PROJECT=""
export TF_VAR_S3_BUCKET=""
export TF_VAR_KINESIS_FIREHOSE=""
```
## S3 Setup for remote state

* Login to AWS CLI
```
rm  -rf ~/.aws/credentials
aws configure
```

* Create S3 bucket for TF State.
```
 aws s3api  create-bucket --bucket $TF_VAR_BUCKET_NAME --region $TF_VAR_REGION
```

## Init TF Backend

```
terraform init --backend-config "bucket=$TF_VAR_BUCKET_NAME" --backend-config "key=$TF_VAR_BUCKET_KEY" --backend-config "region=$TF_VAR_REGION"
```

## Execing TF
* Plan:
```
terraform plan
```
* Execute, taking note of the Redshift Endpoint at the end.
```
terraform -auto-approve
```

## Create Pause/Resume Schedules & Add RAW table
* To just pause Redshift
```
aws redshift pause-cluster --cluster-identifier $TF_VAR_REDSHIFT_NAME 
```
* To just resume Redshift
```
aws redshift resume-cluster --cluster-identifier $TF_VAR_REDSHIFT_NAME 
```
* Create Pause Schedule
```
aws redshift create-scheduled-action --scheduled-action-name resumer --target-action '{"ResumeCluster":{"ClusterIdentifier":"$TF_VAR_REDSHIFT_NAME"}}' --schedule "cron(0 13 ? * MON-FRI *)" --iam-role $(tf output Redshift_Schedule_Role)
```
* Create Resume Schedule
```
aws redshift create-scheduled-action --scheduled-action-name resumer --target-action '{"ResumeCluster":{"ClusterIdentifier":"$TF_VAR_REDSHIFT_NAME"}}' --schedule "cron(0 13 ? * MON-FRI *)" --iam-role $(tf output Redshift_Schedule_Role)
```
## Table Creation
```
aws redshift-data execute-statement --region $TF_VAR_REGION --cluster-identifier $TF_VAR_REDSHIFT_NAME --database $TF_VAR_DB_NAME --sql "create table raw_sentiment (id INT IDENTITY(1,1), loaded_at datetime default sysdate, comprehendpayload varchar(65535), tweetpayload varchar(65535));" --db-user=$TF_VAR_REDSHIFT_USER
```