import os
import signal
import sys
import time
import redis
import requests
from py_zipkin.encoding import Encoding
from py_zipkin.zipkin import zipkin_span, ZipkinAttrs, generate_random_64bit_string

import filters


def run_remaining_filters(ctx):
    """Runs every filter after validate() on an already-validated context.

    validate() runs separately in the main loop below, before this
    function is called, because whether to wrap the rest of the chain in
    a Zipkin span depends on data that only validate() produces (the
    zipkinSpan field of the parsed message).
    """
    for stage in filters.FILTERS[1:]:
        try:
            ctx = stage(ctx)
        except Exception as e:
            filters.notify_error(stage.__name__, e, ctx)
            return None
        if ctx is None:
            return None

    print('processed: {}'.format(ctx.message))
    return ctx.message


def subscribe(host, port, channel, attempts=30):
    # Redis and the network policies can take a few seconds to accept a new pod.
    for attempt in range(attempts):
        try:
            pubsub = redis.Redis(host=host, port=port, db=0).pubsub()
            pubsub.subscribe([channel])
            return pubsub
        except redis.exceptions.ConnectionError:
            if attempt == attempts - 1:
                raise
            print('waiting for redis at {}:{}'.format(host, port))
            time.sleep(2)


if __name__ == '__main__':
    # As the first process of its container, Python would ignore SIGTERM without a handler.
    signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(0))

    redis_host = os.environ['REDIS_HOST']
    redis_port = int(os.environ['REDIS_PORT'])
    redis_channel = os.environ['REDIS_CHANNEL']
    zipkin_url = os.environ['ZIPKIN_URL'] if 'ZIPKIN_URL' in os.environ else ''

    def http_transport(encoded_span):
        requests.post(
            zipkin_url,
            data=encoded_span,
            headers={'Content-Type': 'application/json'},
        )

    pubsub = subscribe(redis_host, redis_port, redis_channel)

    for item in pubsub.listen():
        ctx = filters.validate(filters.PipelineContext(item))
        if ctx is None:
            continue

        if not zipkin_url or 'zipkinSpan' not in ctx.message:
            run_remaining_filters(ctx)
            continue

        span_data = ctx.message['zipkinSpan']
        try:
            with zipkin_span(
                service_name='log-message-processor',
                zipkin_attrs=ZipkinAttrs(
                    trace_id=span_data['_traceId']['value'],
                    span_id=generate_random_64bit_string(),
                    parent_span_id=span_data['_spanId'],
                    is_sampled=span_data['_sampled']['value'],
                    flags=None
                ),
                span_name='save_log',
                transport_handler=http_transport,
                encoding=Encoding.V2_JSON,
                sample_rate=100
            ):
                run_remaining_filters(ctx)
        except Exception as e:
            print('did not send data to Zipkin: {}'.format(e))
            run_remaining_filters(ctx)
