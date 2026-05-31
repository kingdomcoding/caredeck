# syntax=docker/dockerfile:1.7

ARG ELIXIR_VERSION=1.18.1
ARG OTP_VERSION=27.2
ARG DEBIAN_VERSION=bookworm-20241223-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS builder

ENV MIX_ENV=prod LANG=C.UTF-8

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install -y build-essential git curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod && mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix compile
RUN mix assets.deploy
RUN mix release

FROM debian:${DEBIAN_VERSION} AS runner

ENV LANG=C.UTF-8

RUN apt-get update -qq && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates wget imagemagick ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/caredeck ./

EXPOSE 4000
CMD ["/app/bin/caredeck", "start"]
