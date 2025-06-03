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
    if use_library_from_git "python-observabilityclient"; then
        git_clone_by_name "python-observabilityclient"
        setup_dev_lib "python-observabilityclient"
    else
        pip_install_gr python-observabilityclient
    fi
}

function configure_sg-core {
    sudo mkdir -p `dirname $SG_CORE_CONF`
    sudo cp $SG_CORE_DIR/devstack/sg-core-files/sg-core.conf.yaml $SG_CORE_CONF

    # Copy prometheus.yaml file to /etc/openstack
    if [[ $SG_CORE_CONFIGURE_OBSERVABILITYCLIENT = true ]]; then
        sudo mkdir -p /etc/openstack
        sudo cp $SG_CORE_DIR/devstack/observabilityclient-files/prometheus.yaml /etc/openstack/prometheus.yaml
    fi
}

function init_sg-core {
    run_process "sg-core" "$SG_CORE_CONTAINER_EXECUTABLE run -v $SG_CORE_CONF:/etc/sg-core.conf.yaml --network host --name sg-core $SG_CORE_CONTAINER_IMAGE"
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
    rm -rf $SG_CORE_WORKDIR
fi

