function install_container_executable {
	if install_package podman; then
		SG_CORE_CONTAINER_EXECUTABLE=$(which podman)
	elif install_package docker.io; then
		sudo chown stack:docker /var/run/docker.sock
		sudo usermod -aG docker stack
		SG_CORE_CONTAINER_EXECUTABLE=$(which docker)
	else
		echo_summary "Couldn't install podman or docker"
		return 1
	fi
	if is_ubuntu; then
		install_package uidmap
	fi
}

### sg-core ###
function install_sg-core {
	$SG_CORE_CONTAINER_EXECUTABLE pull $SG_CORE_CONTAINER_IMAGE
}

function configure_sg-core {
	sudo mkdir -p `dirname $SG_CORE_CONF`
	sudo cp $SG_CORE_DIR/devstack/sg-core-files/sg-core.conf.yaml $SG_CORE_CONF
}

function init_sg-core {
	run_process "sg-core" "$SG_CORE_CONTAINER_EXECUTABLE run -v $SG_CORE_CONF:/etc/sg-core.conf.yaml --network host --name sg-core $SG_CORE_CONTAINER_IMAGE"
}

### prometheus ###
function configure_prometheus {
	BASE_CONFIG_FILE=$SG_CORE_DIR/devstack/prometheus-files/prometheus.yml
	RESULT_CONFIG_FILE=$SG_CORE_WORKDIR/prometheus.yml

	cat $BASE_CONFIG_FILE > $RESULT_CONFIG_FILE

	SERVICES=$(echo $PROMETHEUS_SERVICE_SCRAPE_TARGETS | tr "," "\n")
	for SERVICE in ${SERVICES[@]}
	do
		cat $SG_CORE_DIR/devstack/prometheus-files/scrape_configs/$SERVICE >> $RESULT_CONFIG_FILE
	done

	if [[ $PROMETHEUS_CUSTOM_SCRAPE_TARGETS != "" ]]; then
		echo "  - job_name: 'custom'" >> $RESULT_CONFIG_FILE
		echo "    static_configs:" >> $RESULT_CONFIG_FILE
		echo "      - targets: [$PROMETHEUS_CUSTOM_SCRAPE_TARGETS]" >> $RESULT_CONFIG_FILE
	fi

	sudo mkdir -p `dirname $PROMETHEUS_CONFIG_FILE`
	sudo cp $RESULT_CONFIG_FILE $PROMETHEUS_CONFIG_FILE

	sudo mkdir -p $PROMETHEUS_CLIENT_CONF_DIR
	sudo cp $SG_CORE_DIR/devstack/observabilityclient-files/prometheus.yaml $PROMETHEUS_CLIENT_CONF_DIR/prometheus.yaml
}


# check for service enabled
if is_service_enabled sg-core; then

	mkdir $SG_CORE_WORKDIR
	if [[ $SG_CORE_ENABLE = true ]]; then
		if [[ "$1" == "stack" && "$2" == "pre-install" ]]; then
			# Set up system services
			echo_summary "Configuring system services for sg-core"
			install_container_executable

		elif [[ "$1" == "stack" && "$2" == "install" ]]; then
			# Perform installation of service source
			echo_summary "Installing sg-core"
			install_sg-core

		elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
			# Configure after the other layer 1 and 2 services have been configured
			echo_summary "Configuring sg-core"
			configure_sg-core

		elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
			# Initialize and start the sg-core service
			echo_summary "Initializing sg-core"
			init_sg-core
		fi

		if [[ "$1" == "unstack" ]]; then
			$SG_CORE_CONTAINER_EXECUTABLE stop sg-core
			$SG_CORE_CONTAINER_EXECUTABLE rm -f sg-core
		fi

		if [[ "$1" == "clean" ]]; then
			$SG_CORE_CONTAINER_EXECUTABLE rmi $SG_CORE_CONTAINER_IMAGE
		fi
	fi
	if [[ $PROMETHEUS_ENABLE = true ]]; then
		if [[ "$1" == "stack" && "$2" == "pre-install" ]]; then
			# Create configuration file for Prometheus deployed by devstack-plugin-prometheus
			echo_summary "Creating Prometheus configuration file for sg-core scraping"
			configure_prometheus
		fi
	fi
	rm -rf $SG_CORE_WORKDIR
fi

