#!/usr/bin/env bash

#
# Main deployment script
#

SERVER_NAME=$1
CONFIG_PATH=../config/${SERVER_NAME}

# source config
CONFIG_FILE=${CONFIG_PATH}/deploy.conf

if [ -e ${CONFIG_FILE} ]; then
  echo "Deploy to ${SERVER_NAME}"
  . ${CONFIG_FILE}
else
  echo "Error: Server configuration '${CONFIG_FILE}' not found!"
  exit 1
fi

echo " - ${SERVER_DESCRIPTION}"

function deployToHeroku {
  echo "Server type: Heroku"
  BRANCH_NAME=`git rev-parse --abbrev-ref HEAD`

  # upsert Heroku remote
  if git remote -v | grep "${SERVER_NAME}" > /dev/null; then
    git remote set-url ${SERVER_NAME} ${HEROKU_REMOTE}
  else
    git remote add ${SERVER_NAME} ${HEROKU_REMOTE}
  fi

  # set root url
  heroku config:add ROOT_URL="${ROOT_URL}" -r ${SERVER_NAME}

  # set Mongo url
  heroku config:add MONGO_URL="${MONGO_URL}" -r ${SERVER_NAME}

  # set Meteor settings
  heroku config:add METEOR_SETTINGS="$(cat ${CONFIG_PATH}/settings.json)" -r ${SERVER_NAME}

  git push -f ${SERVER_NAME} ${BRANCH_NAME}:master
}

function deployToAws {
  echo "Server type: AWS"
  cd ${CONFIG_PATH}
  mupx deploy
}

function deployToGalaxy {
  echo "Server type: Galaxy"
  # todo: add build in env variables to settings.json support
  export DEPLOY_HOSTNAME
  meteor deploy ${DOMAIN_NAME} --owner ${OWNER_ID} --settings ${CONFIG_PATH}/settings.json
}

function verifyDeployment {
  echo "Verifying deployment...";
  sleep ${VERIFY_TIMEOUT}
  curl -o /dev/null -s ${ROOT_URL} && echo "OK" || echo "FAILED"
}

case ${SERVER_TYPE} in
  heroku)
    deployToHeroku
    verifyDeployment
  ;;
  aws)
    deployToAws
  ;;
  galaxy)
    deployToGalaxy
    verifyDeployment
  ;;
  *)
    echo "Unknown server type: ${SERVER_TYPE}"
    exit 1
  ;;
esac

echo "Deployment finished";