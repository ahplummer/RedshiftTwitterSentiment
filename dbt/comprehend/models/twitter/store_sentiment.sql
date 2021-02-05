{{
    config(
        materialized='incremental'
    )
}}

select 
	id as load_id
	,loaded_at
    ,GETDATE() as transformed_at
	,json_extract_path_text(tweetpayload, 'created_at') as created
    ,json_extract_path_text(tweetpayload, 'text') as tweet
    ,json_extract_path_text(tweetpayload, 'user', 'screen_name') as user
    ,json_extract_path_text(comprehendpayload, 'Sentiment') as sentiment
    ,cast(json_extract_path_text(comprehendpayload, 'SentimentScore', 'Positive') as FLOAT) as scorepos
    ,cast(json_extract_path_text(comprehendpayload, 'SentimentScore', 'Negative') as FLOAT) as scoreneg
    ,cast(json_extract_path_text(comprehendpayload, 'SentimentScore', 'Neutral') as FLOAT) as scoreneut          
    ,cast(json_extract_path_text(comprehendpayload, 'SentimentScore', 'Mixed') as FLOAT) as scoremixed
from raw_sentiment rs
{% if is_incremental() %}
  -- this filter will only be applied on an incremental run
  where id not in (select load_id from {{ this }})
  --where event_time > (select max(event_time) from {{ this }})
{% endif %}