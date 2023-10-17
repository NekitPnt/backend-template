FROM python:3.11-alpine AS base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN apk --no-cache add --virtual='.build-deps' 'gcc' 'musl-dev' 'libffi-dev'


####

FROM base AS builder

RUN pip --no-cache install -U 'pip' 'wheel' 'poetry' 'pyc_wheel'

COPY './' '/src/'

WORKDIR '/src/'

ARG DEBUG=0

RUN set -e; \
    export PYTHONOPTIMIZE="$(( ! $DEBUG ))"; \
    poetry build; \
    poetry export "$([[ "$DEBUG" ]] && echo '--with=dev')" -o './dist/requirements.txt'; \
    python -m pyc_wheel ./'dist'/*.whl;


####

FROM base

COPY --from=builder '/src/dist/' '/dist/'

RUN set -e; \
    cd '/dist/'; \
    pip --no-cache install -Ur './requirements.txt'; \
    pip --no-cache install *.whl; \
    rm -rf '/dist/';

RUN set -e; \
    apk del '.build-deps'; \
    apk add --no-cache 'curl';

RUN adduser --disabled-password 'user'

USER user

HEALTHCHECK CMD curl -fs "http://localhost:$PORT/healthcheck" || exit 1

ENTRYPOINT ["/bin/sh", "-c", "exec uvicorn --host '0.0.0.0' --port \"$PORT\" 'api:app' \"$@\""]