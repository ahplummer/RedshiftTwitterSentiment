resource "aws_vpc" "mainvpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Engagement  = var.PROJECT
    Name = "vpc-${var.PROJECT}"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.mainvpc.id
  tags = {
    Engagement = var.PROJECT
    Name = "igw-${var.PROJECT}"
  }
}
resource "aws_eip" "extip" {
  associate_with_private_ip = "10.0.0.50"
  vpc = true
}
resource "aws_nat_gateway" "natgateway" {
  subnet_id = aws_subnet.public.id
  allocation_id = aws_eip.extip.id
  depends_on=[aws_internet_gateway.gw]
  tags = {
    Name="nat-${var.PROJECT}"
    Engagement=var.PROJECT
  }
}

resource "aws_subnet" "public" {
  cidr_block = "10.0.0.0/24"
  vpc_id = aws_vpc.mainvpc.id
  availability_zone = var.VPC_AZ
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-Subnet-${var.PROJECT}"
    Engagement = var.PROJECT
  }
}

resource "aws_subnet" "private" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.mainvpc.id

  availability_zone = var.VPC_AZ
  map_public_ip_on_launch = false
  tags = {
    Name = "Private-Subnet-${var.PROJECT}"
    Engagement = var.PROJECT
  }
}
resource "aws_route_table" "privatert" {
  vpc_id = aws_vpc.mainvpc.id
  tags = {
    Name = "rt-${var.PROJECT}"
    Engagement = var.PROJECT
  }
}

resource "aws_route_table" "publicrt" {
  vpc_id = aws_vpc.mainvpc.id
  tags = {
    Name = "rt-${var.PROJECT}"
    Engagement = var.PROJECT
  }
}

resource "aws_route" "public_inet_gw" {
  route_table_id = aws_route_table.publicrt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id
}

resource "aws_route" "private_nat_gw" {
  route_table_id = aws_route_table.privatert.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.natgateway.id
}

resource "aws_route_table_association" "public"{
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.publicrt.id
}

resource "aws_route_table_association" "private" {
  subnet_id = aws_subnet.private.id
  route_table_id = aws_route_table.privatert.id
}

resource "aws_security_group" "sg" {
  name = "terraformsg"
  vpc_id = aws_vpc.mainvpc.id
  depends_on = [aws_vpc.mainvpc]
  ingress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Engagement = var.PROJECT
  }
}
resource "aws_redshift_subnet_group" "redshift_sgroup" {
  name = "cg-subnetgroup"
  subnet_ids = [aws_subnet.public.id]
  depends_on = [aws_internet_gateway.gw]
  tags = {
    Engagement=var.PROJECT
  }
}

resource "aws_redshift_cluster" "main" {
  cluster_identifier = var.REDSHIFT_NAME
  vpc_security_group_ids = [aws_security_group.sg.id]
  database_name      = var.DB_NAME
  master_username    = var.REDSHIFT_USER
  master_password    = var.REDSHIFT_PASSWORD
  node_type          = "dc2.large"
  cluster_type       = "single-node"
  cluster_subnet_group_name = aws_redshift_subnet_group.redshift_sgroup.name
  skip_final_snapshot = true
  tags = {
    Engagement=var.PROJECT
  }
}


resource "aws_s3_bucket" "s3bucket" {
  bucket = var.S3_BUCKET
  acl = "private"
  force_destroy = true
}
resource "aws_iam_policy" "kinesis_firehose_policy" {
    name        = "kinesis_firehose_policy"
    path        = "/"
    depends_on = [aws_s3_bucket.s3bucket]
    policy      = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "glue:GetTable",
        "glue:GetTableVersion",
        "glue:GetTableVersions"
      ],
      "Resource": [
        "arn:aws:glue:${var.REGION}:${data.aws_caller_identity.current.account_id}:catalog",
        "arn:aws:glue:${var.REGION}:${data.aws_caller_identity.current.account_id}:database/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%",
        "arn:aws:glue:${var.REGION}:${data.aws_caller_identity.current.account_id}:table/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::${var.S3_BUCKET}",
        "arn:aws:s3:::${var.S3_BUCKET}/*"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction",
        "lambda:GetFunctionConfiguration"
      ],
      "Resource": "arn:aws:lambda:${var.REGION}:${data.aws_caller_identity.current.account_id}:function:%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:GenerateDataKey",
        "kms:Decrypt"
      ],
      "Resource": [
        "arn:aws:kms:${var.REGION}:${data.aws_caller_identity.current.account_id}:key/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
      ],
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "s3.us-east-1.amazonaws.com"
        },
        "StringLike": {
          "kms:EncryptionContext:aws:s3:arn": [
            "arn:aws:s3:::%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%/*"
          ]
        }
      }
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:${var.REGION}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/manually:log-stream:*"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "kinesis:DescribeStream",
        "kinesis:GetShardIterator",
        "kinesis:GetRecords",
        "kinesis:ListShards"
      ],
      "Resource": "arn:aws:kinesis:${var.REGION}:${data.aws_caller_identity.current.account_id}:stream/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": [
        "arn:aws:kms:${var.REGION}:${data.aws_caller_identity.current.account_id}:key/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
      ],
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "kinesis.us-east-1.amazonaws.com"
        },
        "StringLike": {
          "kms:EncryptionContext:aws:kinesis:arn": "arn:aws:kinesis:${var.REGION}:${data.aws_caller_identity.current.account_id}:stream/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
        }
      }
    }
  ]
}
POLICY
}


resource "aws_iam_role" "firehose_role" {
    name               = "firehose_role"
    path               = "/"
    assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
resource "aws_iam_role_policy_attachment" "firehose-attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.kinesis_firehose_policy.arn
  depends_on = [
    aws_iam_policy.kinesis_firehose_policy,
    aws_iam_role.firehose_role
  ]
}
resource "aws_iam_role" "redshift-schedule" {
  name = "redshift-schedule"
  path = "/"
  depends_on = [aws_redshift_cluster.main]
      assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "scheduler.redshift.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
resource "aws_cloudwatch_log_group" "firehose" {
  name = "twitter_firehose_loggroup"
  tags = {
    Project = var.PROJECT
  }
}
resource "aws_cloudwatch_log_stream" "firehose-stream" {
  name           = "twitter_firehose_logstream"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}
resource "aws_kinesis_firehose_delivery_stream" "twitter-stream" {
  destination = "redshift"
  name = var.KINESIS_FIREHOSE
  depends_on = [aws_s3_bucket.s3bucket]
  s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.s3bucket.arn
    buffer_size        = 1
    buffer_interval    = 60
    compression_format = "UNCOMPRESSED"
  }
  redshift_configuration {
    role_arn = aws_iam_role.firehose_role.arn
    cluster_jdbcurl = "jdbc:redshift://${aws_redshift_cluster.main.endpoint}/${aws_redshift_cluster.main.database_name}"
    username = var.REDSHIFT_USER
    password = var.REDSHIFT_PASSWORD
    data_table_name = var.DB_RAW_TABLE
    copy_options = "json 'auto';"
    data_table_columns = "tweetpayload,comprehendpayload"
    s3_backup_mode = "Enabled"
    retry_duration = 3600
    cloudwatch_logging_options {
      enabled = true
      log_group_name = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose-stream.name
    }
    s3_backup_configuration {
      bucket_arn = aws_s3_bucket.s3bucket.arn
      role_arn = aws_iam_role.firehose_role.arn
      buffer_interval = 60
      buffer_size = 1
      compression_format = "UNCOMPRESSED"
    }
  }
}
