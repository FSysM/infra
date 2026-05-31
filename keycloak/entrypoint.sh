#!/bin/bash
set -e

echo "Starting Keycloak (start-dev)..."
/opt/keycloak/bin/kc.sh start-dev &
KC_PID=$!

KCADM=/opt/keycloak/bin/kcadm.sh

echo "Waiting for Keycloak to become ready..."
until $KCADM config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user "${KEYCLOAK_ADMIN}" \
  --password "${KEYCLOAK_ADMIN_PASSWORD}" 2>/dev/null; do
  sleep 3
done
echo "Keycloak ready — starting provisioning"

# Realm
$KCADM create realms \
  -s realm=fsysm \
  -s enabled=true \
  -s displayName="FSysM" \
  -s accessTokenLifespan=3600 \
  2>/dev/null && echo "Realm fsysm created" || echo "Realm fsysm already exists"

# Realm roles
for role in STUDENT TEACHER; do
  $KCADM create roles -r fsysm -s name="${role}" 2>/dev/null \
    && echo "Role ${role} created" \
    || echo "Role ${role} already exists"
done

# Client — confidential, for Next.js BFF (authorization code flow + PKCE)
CLIENT_EXISTS=$($KCADM get clients -r fsysm -q clientId=fsysm-app --fields clientId 2>/dev/null | grep -c "fsysm-app" || true)
if [ "$CLIENT_EXISTS" -eq 0 ]; then
  $KCADM create clients -r fsysm \
    -s clientId=fsysm-app \
    -s enabled=true \
    -s publicClient=false \
    -s standardFlowEnabled=true \
    -s serviceAccountsEnabled=false \
    -s 'redirectUris=["https://localhost/*","https://localhost/api/auth/callback/keycloak"]' \
    -s 'webOrigins=["https://localhost"]' \
    -s 'attributes={"pkce.code.challenge.method":"S256"}'
  echo "Client fsysm-app created"
else
  echo "Client fsysm-app already exists"
fi

# Users
create_user() {
  local id="$1" username="$2" email="$3" first="$4" last="$5" role="$6"

  local exists
  exists=$($KCADM get users -r fsysm -q "username=${username}" --fields username 2>/dev/null \
    | grep -c "\"${username}\"" || true)

  if [ "$exists" -gt 0 ]; then
    echo "User ${username} already exists — skipping"
    return
  fi

  $KCADM create users -r fsysm \
    -s "id=${id}" \
    -s "username=${username}" \
    -s "email=${email}" \
    -s "firstName=${first}" \
    -s "lastName=${last}" \
    -s enabled=true

  $KCADM set-password -r fsysm \
    --username "${username}" \
    --new-password "password" \
    --temporary false

  $KCADM add-roles -r fsysm \
    --uusername "${username}" \
    --rolename "${role}"

  echo "User ${username} (${role}) created with id ${id}"
}

#        id                                    username   email                    first    last    role
create_user 2fb9d22a-32d7-48d9-90f4-d9f91c4c8885 student1 student1@email.com Student  One    STUDENT
create_user 46227c5d-24b4-40e9-877f-a98ed9dcbda9 student2 student2@email.com Student  Two    STUDENT
create_user d5412b95-eeff-478a-9ce3-e8323fa95b40 student3 student3@email.com Student  Three  STUDENT
create_user 2cb385e4-f0ec-45bb-afa1-6f4c7f88c8f2 teacher1 teacher1@email.com Teacher  One    TEACHER
create_user 1ca85ea9-133f-4908-8330-610535113232 teacher2 teacher2@email.com Teacher  Two    TEACHER
create_user 5778d982-6325-4f6b-9305-68a82cb49165 teacher3 teacher3@email.com Teacher  Three  TEACHER

echo "Provisioning complete — realm: fsysm | users: student1/2/3 teacher1/2/3 | password: password"

wait $KC_PID
