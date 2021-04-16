#####################################################################
# Init
#####################################################################

export V5_API_DEBUG=0
export V5_WORKSPACE=0

function v5-random-string () {
  cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c10
}

function v5-curl-flags () {
  case "${V5_API_DEBUG}" in
    0) echo "--silent" ;;
    1) echo "--verbose" ;;
  esac
}

function v5-stream () {
  jq -cn --stream 'fromstream(1|truncate_stream(inputs))'
}

function v5-fields () {
  local QUERY=""
  for FIELD in "${@}"; do
    QUERY="$QUERY \"${FIELD}\"  : .${FIELD},"
  done
  jq -r "{ ${QUERY} }"
}

function v5-token () {
  echo -n "${WHISPIR_API_TOKEN}"
}

function v5-auth () {
  echo -n "${WHISPIR_API_USER}:${WHISPIR_API_PASS}" | base64 -
}

function v5-get () {
  local TYP=${1:-""}
  local PTH=${2:-""}
  local QRY=${3:-""}

  if [[ -n "${PTH}" ]]; then
    PTH="/${PTH}"
  fi

  if [[ -n "${QRY}" ]]; then
    QRY="?${QRY}"
  fi

  curl $(v5-curl-flags) \
       --request GET \
       --header 'Accept: application/json' \
       --header "Authorization: Basic $(v5-auth)" \
       --header "x-api-key: $(v5-token)" \
       --header "Content-Type: application/vnd.whispir.${TYP}-v1+json" \
       --header "Accept: application/vnd.whispir.${TYP}-v1+json" \
       "${WHISPIR_API_ENDPOINT}${PTH}${QRY}"
}

function v5-post () {
  local TYP=${1:-""}
  local PTH=${2:-""}
  local DTA=${3:-"{}"}

  if [[ -n "${PTH}" ]]; then
    PTH="/${PTH}"
  fi

  curl $(v5-curl-flags)  \
       --request POST \
       --header 'Accept: application/json' \
       --header "Authorization: Basic $(v5-auth)" \
       --header "x-api-key: $(v5-token)" \
       --header "Content-Type: application/vnd.whispir.${TYP}-v1+json" \
       --header "Accept: application/vnd.whispir.${TYP}-v1+json" \
       --data-raw "${DTA}" \
       "${WHISPIR_API_ENDPOINT}${PTH}"
}

function v5 () {
  [[ $# -gt 0 ]] || {
    _v5::help
    return 1
  }

  local command="$1"
  shift

  (( $+functions[_v5::$command] )) || {
    _v5::help
    return 1
  }

  _v5::$command "$@"
}

function v5-message-show () {
  v5 message list   | jq -r ".messages" | \
    v5-stream | v5-fields id projectName | \
    jq --slurp | jq -r '.[] | "\(.id):\(.projectName)"'
}

function v5-workspace-show () {
  v5 workspace list | jq -r ".workspaces" | \
    v5-stream | v5-fields id projectName | \
    jq --slurp | jq -r '.[] | "\(.id):\(.projectName)"'
}

function v5-contact-show () {
  v5 contact list   | jq -r ".contacts" | \
    v5-stream | v5-fields id firstName lastName | \
    jq --slurp | jq -r '.[] | "\(.id):\(.firstName) \(.lastName)"'
}

function v5-resource-show () {
  v5 resource list   | jq -r ".resources" | \
    v5-stream | v5-fields id name| \
    jq --slurp | jq -r '.[] | "\(.id):\(.name)"'
}

function _v5 {
  if (( CURRENT == 2 )); then
      subcmds=(
        "help:Usage information"
        "debug:Enable debugging curl commands"
        "init:Initialisation information"
        "workspace:Manage Workspaces"
        "contact:Manage Contacts"
        "resource:Manage Resources"
        "message:Manage Messages"
      )
    _describe 'command' subcmds
  elif (( CURRENT == 3 )); then
      subcmds=(
        "list:List ${words[2]}"
        "show:show ${words[2]}"
        "create:Create a new ${words[2]}"
        "import:Import ${words[2]} resource"
        "send:Send ${words[2]}"
      )
      _describe 'command' subcmds
  elif (( CURRENT == 4 )); then
      case "${words[1]}-${words[2]}-${words[3]}" in
          v5-*-create)
            _files ;;
          v5-workspace-select)
            subcmds=("${(@f)$(v5-workspace-show)}")
            _describe 'command' subcmds ;;
          v5-*-show)
            subcmds=("${(@f)$(v5-${words[2]}-show)}")
            _describe 'command' subcmds ;;
          v5-*-import)
            subcmds=("${(@f)$(v5-resource-show)}")
            _describe 'command' subcmds ;;
          v5-*-send)
            subcmds=("${(@f)$(v5-contact-show)}")
            _describe 'command' subcmds ;;
      esac
  fi

  return 0
}

compdef _v5 v5

function _v5::help () {
    cat <<EOF
Usage: v5 <command> [options]

Available commands:

    init         Show initialisation configuration
    help         Show this help
    debug        Toggle debug
    workspace    Manage workspaces
    contact      Manage contacts
    resource     Manage resources
    message      Manage messages

EOF
}

#####################################################################
# Init
#####################################################################

function _v5::init () {
  if [ -n "${WHISPIR_API_USER}" ] && [ -n "${WHISPIR_API_PASS}" ]; then
    echo "============================================="
    echo "WHISPIR_API_TOKEN .... ${WHISPIR_API_TOKEN}"
    echo "WHISPIR_API_USER ..... ${WHISPIR_API_USER}"
    echo "WHISPIR_API_PASS ..... ${WHISPIR_API_PASS}"
    echo "---------------------------------------------"
    echo "V5_API_DEBUG ......... ${V5_API_DEBUG}"
    echo "V5_WORKSPACE ......... ${V5_WORKSPACE}"
    echo "============================================="
  else
    echo "============================================="
    echo "Create a new User and API Token"
    echo "WHISPIR_API_TOKEN=<Token>"
    echo "WHISPIR_API_USER=<User>"
    echo "WHISPIR_API_PASS=<Password>"
    echo "---------------------------------------------"
    echo "V5_API_DEBUG ......... ${V5_API_DEBUG}"
    echo "V5_WORKSPACE ......... ${V5_WORKSPACE}"
    echo "============================================="
  fi
}

#####################################################################
# Debug
#####################################################################

function _v5::debug () {
  export V5_API_DEBUG=$((1-V5_API_DEBUG))
  echo "================================================================"
  echo "Toggle the whispir v5 api curl debug to [${V5_API_DEBUG}]"
  echo "================================================================"
}

#####################################################################
# Workspace
#####################################################################

function _v5::workspace () {
  (( $# > 0 && $+functions[_v5::workspace::$1] )) || {
    cat <<EOF
Usage: v5 workspace <command> [options]

Available commands:

  create [name]
  select [id]
  clear
  show   [id]
  list

EOF
    return 1
  }

  local command="$1"
  shift

  _v5::workspace::$command "$@"
}

function _v5::workspace::list () {
  v5-get "workspace" "workspaces"
}

function _v5::workspace::show () {
  v5-get "workspace" "workspaces/${1}"
}

function _v5::workspace::select () {
  export V5_WORKSPACE=${1:-0}
}

function _v5::workspace::clear () {
  export V5_WORKSPACE=0
}

function _v5::workspace::create () {
  local WORKSPACE=${1:-$(</dev/stdin)}
  if [[ -f ${WORKSPACE} ]]; then
    v5-post "workspace" "workspaces" "$(cat ${WORKSPACE})"
  elif [[ -n ${WORKSPACE} ]]; then
    v5-post "workspace" "workspaces" "{                         \
      \"projectName\" : \"${WORKSPACE}\",                        \
      \"billingcostcentre\" : \"$(wsp-random-string)\",          \
      \"status\" : \"A\"                                         \
}"
  else
    v5-post "workspace" "workspaces" "{                         \
      \"projectName\" : \"$(wsp-random-string)\",                \
      \"billingcostcentre\" : \"$(wsp-random-string)\",          \
      \"status\" : \"A\"                                         \
}"
  fi
}

#####################################################################
# Contact
#####################################################################

function _v5::contact () {
  (( $# > 0 && $+functions[_v5::contact::$1] )) || {
    cat <<EOF
Usage: v5 contact <command> [options]

Available commands:

  create [name]
  show   [id]
  list

EOF
    return 1
  }

  local command="$1"
  shift

  _v5::contact::$command "$@"
}

function _v5::contact::list () {
  case "${V5_WORKSPACE}" in
    0) v5-get "contact" "contacts" ;;
    *) v5-get "contact" "workspaces/${V5_WORKSPACE}/contacts" ;;
  esac
}

function _v5::contact::show () {
  case "${V5_WORKSPACE}" in
    0) v5-get "contact" "contacts/${1}" ;;
    *) v5-get "contact" "workspaces/${V5_WORKSPACE}/contacts/${1}" ;;
  esac
}

function _v5::contact::import () {
  local RESOURCE=${1:-""}
  if [[ -n ${RESOURCE} ]]; then
    RESOURCE="{                                                   \
    \"resourceId\"     : \"${RESOURCE}\",                         \
    \"importType\"     : \"contact\",                             \
    \"importOptions\": {                                          \
      \"fieldMapping\" : {                                        \
            \"firstName\"         : \"FirstName\",                \
            \"lastName\"          : \"LastName\",                 \
            \"workEmailAddress1\" : \"WorkEmailAddressPrimary\",  \
            \"workMobilePhone1\"  : \"WorkMobilePhonePrimary\",   \
            \"workCountry\"       : \"WorkCountry\",              \
            \"timezone\"          : \"Timezone\",                 \
            \"role\"              : \"Role\"                      \
      },                                                          \
      \"importMode\" : \"replace\"                                \
    }                                                             \
}"
  fi

  case "${V5_WORKSPACE}" in
    0) v5-post "importcontact" "imports" "${RESOURCE}" ;;
    *) v5-post "importcontact" "workspaces/${V5_WORKSPACE}/imports" "${RESOURCE}" ;;
  esac
}

function _v5::contact::create () {
  local CONTACT=${1:-$(</dev/stdin)}

  if [[ -f ${CONTACT} ]]; then
    CONTACT=$(cat ${CONTACT})
  fi

  if [[ -z "${CONTACT}" ]]; then
    CONTACT="{                                                                      \
    \"firstName\"         : \"$(wsp-random-string)\",                               \
    \"lastName\"          : \"$(wsp-random-string)\",                               \
    \"status\"            : \"A\",                                                  \
    \"timezone\"          : \"Australia/Melbourne\",                                \
    \"workEmailAddress1\" : \"$(wsp-random-string)@$(wsp-random-string).com\",      \
    \"workMobilePhone1\"  : \"614$(wsp-random-number)$(wsp-random-number)\",        \
    \"workCountry\"       : \"Australia\",                                          \
    \"locations\" : [{                                                              \
          \"longitude\" : -12.4964,                                                 \
          \"latitude\"  : 41.9028,                                                  \
          \"type\"      : \"CurrentLocation\"                                       \
    }],                                                                             \
    \"messagingoptions\" : [{                                                       \
          \"channel\" : \"sms\",                                                    \
          \"enabled\" : \"true\",                                                   \
          \"primary\" : \"WorkMobilePhone1\"                                        \
        },{                                                                         \
          \"channel\" : \"email\",                                                  \
          \"enabled\" : \"true\",                                                   \
          \"primary\" : \"WorkEmailAddress1\"                                       \
        },{                                                                         \
          \"channel\" : \"voice\",                                                  \
          \"enabled\" : \"true\",                                                   \
          \"primary\" : \"WorkMobilePhone1\"                                        \
    }]                                                                              \
}"
  fi

  case "${V5_WORKSPACE}" in
    0) v5-post "contact" "contacts" "${CONTACT}" ;;
    *) v5-post "contact" "workspaces/${V5_WORKSPACE}/contacts" "${CONTACT}" ;;
  esac
}

#####################################################################
# Resource
#####################################################################

function _v5::resource () {
  (( $# > 0 && $+functions[_v5::resource::$1] )) || {
    cat <<EOF
Usage: v5 resource <command> [options]

Available commands:

  create [name]
  show   [id]
  list

EOF
    return 1
  }

  local command="$1"
  shift

  _v5::resource::$command "$@"
}

function _v5::resource::list () {
  case "${V5_WORKSPACE}" in
    0) v5-get "resource" "resources" ;;
    *) v5-get "resource" "workspaces/${V5_WORKSPACE}/resources" ;;
  esac
}

function _v5::resource::show () {
  case "${V5_WORKSPACE}" in
    0) v5-get "resource" "resources/${1}" ;;
    *) v5-get "resource" "workspaces/${V5_WORKSPACE}/resources/${1}" ;;
  esac
}

function _v5::resource::create () {
  local RESOURCE=${1:-$(</dev/stdin)}

  if [[ -f ${RESOURCE} ]]; then
    RESOURCE="{                                           \
    \"name\"     : \"${RESOURCE}\",                       \
    \"scope\"    : \"private\",                           \
    \"mimeType\" : \"text/csv\",                          \
    \"derefUri\" : \"$(cat ${RESOURCE} | base64 -)\"      \
  }"
  fi

  case "${V5_WORKSPACE}" in
    0) v5-post "resource" "resources" "${RESOURCE}" ;;
    *) v5-post "resource" "workspaces/${V5_WORKSPACE}/resources" "${RESOURCE}" ;;
  esac
}

#####################################################################
# Message
#####################################################################

function _v5::message () {
  (( $# > 0 && $+functions[_v5::message::$1] )) || {
    cat <<EOF
Usage: v5 message <command> [options]

Available commands:

  create [name]
  show   [id]
  list

EOF
    return 1
  }

  local command="$1"
  shift

  _v5::message::$command "$@"
}

function _v5::message::list () {
  case "${V5_WORKSPACE}" in
    0) v5-get "message" "messages" ;;
    *) v5-get "message" "workspaces/${V5_WORKSPACE}/messages" ;;
  esac
}

function _v5::message::show () {
  case "${V5_WORKSPACE}" in
    0) v5-get "message" "messages/${1}" ;;
    *) v5-get "message" "workspaces/${V5_WORKSPACE}/messages/${1}" ;;
  esac
}

