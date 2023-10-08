FROM python:3.10.12-slim as venv

RUN apt-get update \
    && apt-get install -y \
         curl \
         build-essential \
         libffi-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSL https://install.python-poetry.org | python3 -

WORKDIR /app

COPY pyproject.toml poetry.lock ./

RUN python -m venv --copies /app/venv

RUN . /app/venv/bin/activate && pip install poetry && poetry install

FROM python:3.10.12-slim as prod

RUN apt-get update \
    && apt-get install -y \
         curl \
         build-essential \
         libffi-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=venv /app/venv /app/venv/

ENV PATH /app/venv/bin:$PATH

WORKDIR /app

# Code specific copy
COPY . ./

# Copy pytorch model over to repo
COPY ./distilbert-base-uncased-finetuned-sst2 ./

EXPOSE 8000

HEALTHCHECK --interval=5s --timeout=15s --start-period=5s --retries=3 CMD curl --fail http://localhost:8000/health || exit 1

CMD ["uvicorn", "mlapi.src.main:app", "--proxy-headers", "--host", "0.0.0.0", "--port", "8000"]

ENV REDIS_HOST=redis
ENV REDIS_PORT=6379
