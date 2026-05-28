#!/bin/bash

# logging functions
daas_log() {
    local type="$1"
    shift
    printf '%s [%s] [Entrypoint]: %s\n' "$(date --rfc-3339=seconds)" "$type" "$*"
}

daas_note() {
    daas_log INFO "$@"
}

daas_warn() {
    daas_log Warn "$@" >&2
}

daas_error() {
    daas_log ERROR "$@" >&2
    exit 1
}

if [[ -z $TAPDATA_WORK_DIR ]]; then
    TAPDATA_WORK_DIR=/tapdata/apps
fi

# 检查是否是其它脚本引用
_is_sourced() {
    # https://unix.stackexchange.com/a/215279
    [ "${#FUNCNAME[@]}" -ge 2 ] \
        && [ "${FUNCNAME[0]}" = '_is_sourced' ] \
        && [ "${FUNCNAME[1]}" = 'source' ]
}

# usage: file_env VAR [DEFAULT]
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        daas_error "Both $var and $fileVar are set (but are exclusive)"
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

docker_setup_env() {
    file_env 'MONGODB_USER'
    file_env 'MONGODB_PASSWORD'
    file_env 'MONGODB_CONNECTION_STRING'
    file_env 'BACKENDURL'
    file_env 'MODULE'
}

docker_tapdata_start() {
    daas_note "Waiting for tapdata startup"
    if [ -z "$MODULE" ]; then
        rm -rf ~/.local/*
        chmod +x /tapdata/apps/tapdata
        /tapdata/apps/tapdata status --workDir $TAPDATA_WORK_DIR
        /tapdata/apps/tapdata stop -f
        /tapdata/apps/tapdata start
    else
        rm -rf ~/.local/*
        /tapdata/apps/tapdata start $MODULE --workDir $TAPDATA_WORK_DIR
    fi
}

logrotate() {
    # 删除修改时间3天以前的日志
    cd /root/
    find ./ -maxdepth 1 -mtime +3 | grep 2023.* | xargs -I {} rm -rf {}
    # 将当前的current格式化归档
    mv $TAPDATA_WORK_DIR/ ~/$(date "+%Y-%m-%d-%H:%M:%S")
}

set_license() {
    echo "get license..."
    if [[ -z $LICENSE_HOST ]]; then
      LICENSE_HOST=192.168.1.184:18080
    fi
    echo "login..."
    curl -v -XPOST -H "Content-Type:application/json" http://$LICENSE_HOST/ldap/login -d '{"password": "Gotapd8!", "uid": "license-temp"}'
    if [[ $? -ne 0 ]]; then
        echo "login failed"
        exit 1
    fi
    echo "Get SID..."
    SID=$(java -cp /tapdata/apps/components/tm.jar -Dloader.main=com.tapdata.tm.license.util.SidGenerator org.springframework.boot.loader.launch.PropertiesLauncher | grep "SID:" | cut -d ' ' -f 2-)
    echo "SID: $SID"
    resp_json=$(curl -sb -XPOST -H "Content-Type:application/json" -H "uid:license-temp" http://$LICENSE_HOST/license -d '{"customer": "test", "reason": "本地测试", "sid": "'$SID'", "valid_days": 30, "version": "4.7", "licenseType": "OP", "engineLimit": 1}')
    apt install -y jq
    path=$TAPDATA_WORK_DIR
    # logrotate
    mkdir -p $path
    mkdir -p ~/.tapdata
    echo $resp_json | jq -r .data.content > $path/license.txt
    echo $resp_json | jq -r .data.content > ~/.tapdata/license.txt
    if [[ -f $path/license.txt && -f ~/.tapdata/license.txt ]]; then
        ls -al $path/license.txt
        ls -al ~/.tapdata/license.txt
        echo "set license file success."
    else
        echo "set license file failed."
    fi
}

docker_setup_tapdata() {
    # 创建一个临时文件来进行修改
    TMP_CONFIG=$(mktemp)
    cp /tapdata/apps/application.yml $TMP_CONFIG

    if [ -n "$MONGODB_USER" ]; then
        sed -ri "s#username:.*#username: $MONGODB_USER#" $TMP_CONFIG
    fi

    if [ -z "$MONGODB_CONNECTION_STRING" ]; then
        daas_error "MONGODB_CONNECTION_STRING not set.\n Did you forget to add -e MONGODB_CONNECTION_STRING=... ?"
    else
        sed -ri "s#(mongoConnectionString:.*').*(')#\1$MONGODB_CONNECTION_STRING\2#" $TMP_CONFIG
    fi

    if [ -n "$BACKENDURL" ]; then
        sed -ri "s#(backendUrl:.*').*(')#\1$BACKENDURL\2#" $TMP_CONFIG
    fi

    # 将修改后的配置复制到工作目录
    mkdir -p $TAPDATA_WORK_DIR
    cp $TMP_CONFIG $TAPDATA_WORK_DIR/application.yml
    rm -f $TMP_CONFIG

    if [ -n "$MONGODB_PASSWORD" ]; then
        /tapdata/apps/tapdata status --workDir $TAPDATA_WORK_DIR
        /tapdata/apps/tapdata resetpassword $MONGODB_PASSWORD
    fi
}

unzip_files() {
    tar xzvf /tapdata/apps/connectors/dist.tar.gz -C /tapdata/apps/
    cd /tapdata/apps/connectors/ && tar xzvf dist.tar.gz
    tar xzvf /tapdata/apps/components/apiserver.tar.gz -C /tapdata/apps/
}

setup_java() {
    if [[ -z "$JAVA_VERSION" || $JAVA_VERSION == "java8" ]]; then
        daas_log INFO "Setting up java version: java8"
        update-alternatives --set java /usr/java/jdk1.8.0_311/bin/java
        update-alternatives --set javac /usr/java/jdk1.8.0_311/bin/javac
        update-alternatives --set jar /usr/java/jdk1.8.0_311/bin/jar
        echo 'export PATH="/usr/java/jdk1.8.0_311/bin:$PATH"' >> /etc/profile && . /etc/profile
    elif [[ $JAVA_VERSION == "java11" ]]; then
        daas_log INFO "Setting up java version: java11"
        update-alternatives --set java /usr/java/jdk-11.0.25/bin/java
        update-alternatives --set javac /usr/java/jdk-11.0.25/bin/javac
        update-alternatives --set jar /usr/java/jdk-11.0.25/bin/jar
        echo 'export PATH="/usr/java/jdk-11.0.25/bin:$PATH"' >> /etc/profile && . /etc/profile
    elif [[ $JAVA_VERSION == "java17" ]]; then
        daas_log INFO "Setting up java version: java17"
        update-alternatives --set java /usr/java/jdk-17.0.12/bin/java
        update-alternatives --set javac /usr/java/jdk-17.0.12/bin/javac
        update-alternatives --set jar /usr/java/jdk-17.0.12/bin/jar
        echo 'export PATH="/usr/java/jdk-17.0.12/bin:$PATH"' >> /etc/profile && . /etc/profile
    else
        daas_error "Unsupported JAVA_VERSION: $JAVA_VERSION"
    fi
}

_main() {
    setup_java

    cp /tmp/conf/application.yml /tapdata/apps/application.yml
    echo "export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8" >> /etc/profile && . /etc/profile
    unzip_files
    set_license

    daas_note "Entrypoint script for tapmanager Server started."

    # Load various environment variables
    docker_setup_env "$@"

    db=$(echo $MONGODB_CONNECTION_STRING | awk -F '/' '{print $2}' | awk -F '?' '{print $1}')
    TAPDATA_MONGO_URI="mongodb://root:$MONGODB_PASSWORD@$MONGODB_CONNECTION_STRING"
    echo "restore data to db: $db, to uri: ${TAPDATA_MONGO_URI}"

    docker_setup_tapdata
    if [[ $TAPDATA_WORK_DIR != "" && -d /tapdata/apps/components/webroot/ ]]; then
        mkdir -p $TAPDATA_WORK_DIR/components/webroot/
        cp -r /tapdata/apps/components/webroot/* $TAPDATA_WORK_DIR/components/webroot/
    fi

    daas_note "Starting tapdata server"
    docker_tapdata_start
    daas_note "tapdata server started."

    exec "$@"
}

# 如果是其它脚本引用，则不执行操作
if ! _is_sourced; then
    _main "$@"
fi

while [[ 1 ]]; do
    sleep 10
done
