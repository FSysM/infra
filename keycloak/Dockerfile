FROM quay.io/keycloak/keycloak:latest AS builder

ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_DB=postgres
ENV KC_HTTP_ENABLED=true

WORKDIR /opt/keycloak

RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:latest

COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENV KC_DB=postgres
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

COPY realm-import.json /opt/keycloak/data/import/realm-import.json

USER 1000

# start (production mode) with HTTP listener enabled.
# TLS termination is handled by Traefik — Keycloak only serves HTTP internally.
# --import-realm is a no-op if the realm already exists in the database.
CMD ["start", "--optimized", "--import-realm"]
