import logging
import json
import redis

from fastapi import FastAPI
from pydantic import BaseModel
from transformers import AutoModelForSequenceClassification, AutoTokenizer, pipeline
from typing import List


redis_instance = redis.Redis(host='redis', port=6379, db=0)
model_path = "./distilbert-base-uncased-finetuned-sst2"

model = AutoModelForSequenceClassification.from_pretrained(model_path)
tokenizer = AutoTokenizer.from_pretrained(model_path)
classifier = pipeline(
    task="text-classification",
    model=model,
    tokenizer=tokenizer,
    device=-1,
    top_k=None,
)

logger = logging.getLogger(__name__)
app = FastAPI()


@app.on_event("startup")
def startup():
    redis_instance.flushall()


class SentimentRequest(BaseModel):
    text: List[str]


class Sentiment(BaseModel):
    label: str
    score: float


class SentimentResponse(BaseModel):
    predictions: List[List[Sentiment]]


@app.post("/predict", response_model=SentimentResponse)
def predict(sentiments: SentimentRequest):

    # Attempt to see if result exists in redis cache before computation
    cache_key = json.dumps({"text": sentiments.text})
    cache = redis_instance.get(cache_key)

    if cache:
        res = json.loads(cache)
    else:
        predictions = classifier(sentiments.text)
        formatted_predictions = []

        for preds in predictions:
            formatted_prediction = [Sentiment(label=p.get("label"), score=p.get("score")) for p in preds]
            formatted_predictions.append(formatted_prediction)

        res = SentimentResponse(predictions=formatted_predictions)

        # Cache results if it doesn't already exist with an expiration (in seconds)
        redis_instance.set(cache_key, json.dumps(res.dict()), ex=90)

    return res


@app.get("/health")
async def health():
    return {"status": "healthy"}
