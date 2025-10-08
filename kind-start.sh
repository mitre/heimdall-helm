#!/bin/bash

while getopts "u:p:c:" o; do
    case "${o}" in
        u)
            pull_secret_username=${OPTARG}
            ;;
        p)
            pull_secret_password=${OPTARG}
            ;;
        c)
            cert_path=${OPTARG}
            ;;
        *)
            # usage
            echo "nice"
            ;;
    esac
done
shift $((OPTIND-1))

# cluster configuration for Kind
kind_conf=$(cat << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
)

# if a cert is needed, this will mount a local path with your cert into Kind control plane
if [[ $cert_path ]]; then
kind_conf=$(echo "$kind_conf" && cat << EOF
  extraMounts:
   - hostPath: ${cert_path}
     containerPath: /usr/local/share/ca-certificates/mitre-ca-bundle.crt
containerConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.configs."*".tls]
      ca_file = "/usr/local/share/ca-certificates/mitre-ca-bundle.crt"
    [plugins."io.containerd.grpc.v1.cri".registry.configs.tls]
      ca_file = "/usr/local/share/ca-certificates/mitre-ca-bundle.crt"
EOF
)
fi
echo "Starting kind with the following config:"
echo "${kind_conf}"

# start kind cluster with conf
kind create cluster --config /dev/stdin <<EOF
${kind_conf}
EOF

# run update-ca-certificates so Kind can pull images from outside MITRE
CONTROL_PLANE=$(docker container ls -af 'name=kind-control-plane' --format '{{.ID}}')
docker exec "$CONTROL_PLANE" update-ca-certificates
