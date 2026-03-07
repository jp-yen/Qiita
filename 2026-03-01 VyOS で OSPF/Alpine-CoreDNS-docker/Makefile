SHELL = /bin/sh

conf:
	@# .env を生成 (./coredns/hosts.template を読むので注意)
	HOST_IP=$$(ip -4 -br a | awk '!/^(lo|docker)/{sub("/.*", "", $$3); print $$3; exit}') ; \
	FRR_HOST=$$(awk -v ip="$$HOST_IP" '$$1 == ip {print $$3}' ./coredns/hosts.template) ; \
	DNS_HOST=$$(awk -v ip="$$HOST_IP" '$$1 == ip {print $$2}' ./coredns/hosts.template) ; \
	OSPF_AREA=$$(ip -4 route show scope link proto kernel | awk '!/(lo|docker[0-9])/{sub(/\/.*/, "", $$1); print $$1; exit}') ; \
	sed -e "s/\$${HOST_IP}/$$HOST_IP/g" \
	    -e "s/\$${FRR_HOST_NAME}/$$FRR_HOST/g" \
	    -e "s/\$${COREDNS_HOST_NAME}/$$DNS_HOST/g" \
	    -e "s/\$${OSPF_AREA}/$$OSPF_AREA/g" \
	    .env.template > .env.tmp && mv .env.tmp .env

	@# .env から各設定ファイルを作成
	awk -F= 'NR==FNR {if(!/^#/ && NF>0) env[$$1]=$$2; next} {for(k in env) gsub("\\$${"k"}", env[k], $$0); print}' .env ./frr/frr.conf.template > ./frr/frr.conf
	awk -F= 'NR==FNR {if(!/^#/ && NF>0) env[$$1]=$$2; next} {for(k in env) gsub("\\$${"k"}", env[k], $$0); print}' .env ./coredns/hosts.template > ./coredns/hosts

show_ospf:
	@# OSPF の状態確認 (コマンドを vtysh に流し込む)
	printf "show running-config\n\n \
	show ip route\n\n \
	show ip route ospf\n\n \
	show ip ospf neighbor\n\n \
	show ip ospf database\n\n \
	show ip ospf interface\n" | docker exec -i frr vtysh
	@# docker exec frr vtysh -c "show ip ospf neighbor"

restart:
	# 停止
	docker compose down
	# 起動
	docker compose up -d
