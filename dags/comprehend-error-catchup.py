import codecs
import logging
from datetime import timedelta, datetime
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.operators.bash_operator import BashOperator
from airflow.utils import dates
import pendulum
from comprehend.CatchupErrors import *

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
        schedule_interval='30 13 * * *',
        catchup=False,
        is_paused_upon_creation=False
    )

    def task_start_errorcatchup(**kwargs):
        logger.info('=====Executing task_start_errorcatchup=============')
        execProcessErrors()
        return kwargs['message']

    with new_dag:
        task1 = PythonOperator(
            task_id='Task_Start_ErrorCatchup',
            python_callable=task_start_errorcatchup,
            op_kwargs={'message': 'Starting up Error Handler'},
            provide_context=True,
        )
        return new_dag

dag_id = "Amazon-Redshift-From-S3-Catchup"
globals()[dag_id] = create_dag(dag_id)
