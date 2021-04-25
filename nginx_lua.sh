#!/bin/bash

declare -A HOST_DICT
declare -A ACTION_DICT
declare -A ADM_ENTRY
NGINX_SERVER="172.16.0.2 172.16.0.3 172.16.0.75"
HOST_DICT=([tag1]="172.16.0.5:9000" [tag2]="172.16.0.6:9000")
ACTION_DICT=([list]="list" [add]="add" [del]="del" [status]="status")
ADM_ENTRY=([tag1]="172.16.0.14:9001 " [tag2]="172.16.0.15:900")
USAGE="args: [-a , -t , -dp , -op, -limit] [--action=, --tag=, --dp=,  --op==,  --limit==]"
CURL_ACCOUNT="vrtest:test99999"


# 操作动作
ACTION=""
# Tag类型
TAG=""
# 操作类型(host,tag)
DP=""
# 部署类型(前端,后端, 默认后端)
OP=""

# 限制来源访问, 默认为公司出口IP: 99.99.99.99
LIMIT=""


while [[ $# -gt 0 ]]

do
        key="$1"
        case $key in
                -a|--action) ACTION=$2; shift 2;;
                -t|--tag) TAG=$2; shift 2;;
                -dp|--deploy) DP=$2; shift 2;;
                -op|--operate) OP=$2; shift 2;;
                -l|--limit) LIMIT=$2; shift 2;;
                --) break ;;
                *) echo $USAGE;exit ;;
        esac
done

if [ "${ACTION_DICT[${ACTION}]}"  == "" ];then
   echo "没有此动作"
   exit 1
fi

if [ "${ACTION_DICT[${ACTION}]}"  == "status" ] ;then
  for v in $NGINX_SERVER;do
        echo  -e "在服务器$v上的负载信息\n"
        curl -u "$CURL_ACCOUNT" "http://$v/nginx/host/?action=list"
  done
  exit 1
fi




if [ x"${TAG}" == "x" ];then
   echo "Tag 不能为空"
   exit
fi


if [ "${DP}" == "tag" ];then 
   if [ "x${LIMIT}" == "x" ];then
        LIMIT="99.99.99.99"
   else
        LIMIT=$LIMIT
   fi
   url="/nginx/tag/?action=${ACTION}&tag=${TAG}&sip=${LIMIT}"
else
   url="/nginx/host/?action=${ACTION}&tag=${TAG}"
fi

if [ "x${OP}" == "x" ]; then
   # 默认为后端backend简写ba, 另frontend 简写fr
   OP="ba"
fi

for server in $NGINX_SERVER;do
    if [[ $OP == 'fr' ]];then
        if [ $TAG == "tag1" -o $TAG == "tag2" ];then
            sed_data=""
            for t in ${ADM_ENTRY[${TAG}]};do
              if [ $ACTION == "add" ]; then
                 sed_regex="-e \"/$t/s/^.*$/        server $t;/g\" ";
              elif [ $ACTION == "del" ];then
                 sed_regex="-e \"/$t/s/^.*$/        server $t down;/g\" ";
              else
                 echo "参数不对";
                 exit;
              fi
              sed_data=$sed_data$sed_regex 
            done
            ansible $server -m shell -a "sed -i  $sed_data /usr/local/nginx/conf/vhosts/*.conf;/usr/local/nginx/sbin/nginx -s reload" -u weihu
        fi
    else
        if [[ $server == "172.16.0.75" ]];then
           continue
        fi 

        if [[ ${DP} == "tag" ]];then
            curl -u "$CURL_ACCOUNT" "http://$server$url"
        else
            for i in ${HOST_DICT[${TAG}]};do
                curl -u "$CURL_ACCOUNT" "http://$server$url&host=$i"
            done
        fi
    fi
done