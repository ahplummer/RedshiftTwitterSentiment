import codecs
import logging
from datetime import timedelta, datetime
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.operators.bash_operator import BashOperator
from airflow.utils import dates
import pendulum
from comprehend.TweetSentiment import *

logging.basicConfig(
    format="%(name)s-%(levelname)s-%(asctime)s-%(message)s", level=logging.INFO
)

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def create_dag(dag_id):
    default_args = {
        "owner": "airflow",
        "description": ("DAG to drive AWS Sentiment example"),
        "depends_on_past": False,
        "start_date": dates.days_ago(1),
        "retries": 1,
        "retry_delay": timedelta(minutes=1),
        "provide_context": True,
    }

    new_dag = DAG(
        dag_id,
        default_args=default_args,
        schedule_interval=timedelta(minutes=5),
        catchup=False,
        is_paused_upon_creation=False
    )

    def task_start_comprehend(**kwargs):
        logger.info('=====Executing task_start_comprehend=============')
        execTwitter()
        return kwargs['message']

    with new_dag:
        task1 = PythonOperator(
            task_id='Task_Start_Comprehend',
            python_callable=task_start_comprehend,
            op_kwargs={'message': 'Starting up Comprehend'},
            provide_context=True,
        )
        task2 = BashOperator(
            task_id="Transform_via_DBT",
            bash_command="cd /opt/airflow/dbt/comprehend && dbt run --profiles-dir ./.dbt",
        )

        task2.set_upstream(task1)
        return new_dag

dag_id = "Amazon-Comprehend-Twitter-Sentiment"
globals()[dag_id] = create_dag(dag_id)
