#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: jdacode
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/comfyanonymous/ComfyUI

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  git \
  nvtop
msg_ok "Installed Dependencies"

application_name="${APPLICATION}"
app_path="/opt/${application_name}"
python_path="${app_path}/venv/bin/python"
skip_user_config="${skip_user_config:-N}"
comfyui_version="${comfyui_version:-latest}"
python_version_uv="${python_version_uv:-3.12}"
port_arg="${port_arg:-8188}"
comfyui_python_args="${comfyui_python_args:---cpu}"
gpu_type="${gpu_type:-none}"
comfyui_python_index_url_nvidia="${comfyui_python_index_url_nvidia:-https://download.pytorch.org/whl/cu128}"
comfyui_python_index_url_amd="${comfyui_python_index_url_amd:-https://download.pytorch.org/whl/rocm6.3}"
comfyui_python_index_url_intel="${comfyui_python_index_url_intel:-https://download.pytorch.org/whl/xpu}"
comfyui_manager_enabled="${comfyui_manager_enabled:-Y}"

if ! [[ "${skip_user_config,,}" =~ ^(y|yes)$ ]]; then
  echo
  echo
  echo "${TAB3}${TAB3}Choose the GPU type for ComfyUI:"
  echo "${TAB3}${TAB3}-------------------------------"
  echo "${TAB3}${TAB3}${TAB3}  1. None"
  echo "${TAB3}${TAB3}${TAB3}  2. NVIDIA"
  echo "${TAB3}${TAB3}${TAB3}  3. AMD"
  echo "${TAB3}${TAB3}${TAB3}  4. Intel"
  echo
  read -rp "${TAB3}${TAB3}${TAB3}Enter your choice [1-4] (default: 1): " gpu_choice
  gpu_choice=${gpu_choice:-1}
  case "$gpu_choice" in
    1) gpu_type="none";;
    2) gpu_type="nvidia";;
    3) gpu_type="amd";;
    4) gpu_type="intel";;
    *) gpu_type="none"; echo "${TAB3}${TAB3}${TAB3}${TAB3}Invalid choice. Defaulting to ${gpu_type}." ;;
  esac

  echo
  echo
  echo "${TAB3}${TAB3}Enter additional ComfyUI python args: "
  echo "${TAB3}${TAB3}-------------------------------"
  echo
  echo "${TAB3}${TAB3}Current ExecStart command: main.py --listen --port ${port_arg} ===> ${comfyui_python_args}"
  echo
  read -re -i "${comfyui_python_args}" -p "${TAB3}${TAB3}${TAB3}main.py --listen --port ${port_arg} ===>  " comfyui_python_args

  echo
  echo
  read -rp "${TAB3}${TAB3}Enable ComfyUI-Manager? [Y/n]: " comfyui_manager_enabled
  comfyui_manager_enabled=${comfyui_manager_enabled:-y}
fi

echo -e "${CM}${BOLD}${DGN}Application name           : ${BGN}${application_name}${CL}"
echo -e "${CM}${BOLD}${DGN}Application path           : ${BGN}${app_path}${CL}"
echo -e "${CM}${BOLD}${DGN}ComfyUI version            : ${BGN}${comfyui_version}${CL}"
echo -e "${CM}${BOLD}${DGN}GPU                        : ${BGN}${gpu_type}${CL}"
echo -e "${CM}${BOLD}${DGN}Port                       : ${BGN}${port_arg}${CL}"
echo -e "${CM}${BOLD}${DGN}ComfyUI Manager            : ${BGN}${comfyui_manager_enabled}${CL}"
echo -e "${CM}${BOLD}${DGN}Python version (uv)        : ${BGN}${python_version_uv}${CL}"
echo -e "${CM}${BOLD}${DGN}Python path (uv)           : ${BGN}${python_path}${CL}"
echo -e "${CM}${BOLD}${DGN}ComfyUI python args        : ${BGN}${comfyui_python_args}${CL}"
echo -e "${CM}${BOLD}${DGN}Pip Nvidia index-url       : ${BGN}${comfyui_python_index_url_nvidia}${CL}"
echo -e "${CM}${BOLD}${DGN}Pip AMD index-url          : ${BGN}${comfyui_python_index_url_amd}${CL}"
echo -e "${CM}${BOLD}${DGN}Pip Intel index-url        : ${BGN}${comfyui_python_index_url_intel}${CL}"
echo -e "${CM}${BOLD}${DGN}Preview ExecStart command  : ${BGN}main.py --listen --port ${port_arg} ${comfyui_python_args}${CL}"

msg_info "Setup uv"
PYTHON_VERSION="${python_version_uv}" setup_uv
msg_ok "Setup uv"

fetch_and_deploy_gh_release "${application_name}" "comfyanonymous/ComfyUI" "tarball" "${comfyui_version}" "${app_path}"

msg_info "Python dependencies"
$STD uv venv "${app_path}/venv"
if [[ "${gpu_type,,}" == "nvidia" ]]; then
  echo "NVIDIA GPU selected"
  $STD uv pip install \
      torch \
      torchvision \
      torchaudio \
      --extra-index-url "${comfyui_python_index_url_nvidia}" \
      --python="${python_path}"
elif [[ "${gpu_type,,}" == "amd" ]]; then
  echo "AMD GPU selected"
  $STD uv pip install \
      torch \
      torchvision \
      torchaudio \
      --index-url "${comfyui_python_index_url_amd}" \
      --python="${python_path}"
elif [[ "${gpu_type,,}" == "intel" ]]; then
  echo "Intel GPU selected"
  $STD uv pip install \
      torch \
      torchvision \
      torchaudio \
      --index-url "${comfyui_python_index_url_intel}" \
      --python="${python_path}"
else
  echo "No GPU selected"
fi
$STD uv pip install -r "${app_path}/requirements.txt" --python="${python_path}"
msg_ok "Python dependencies"

if [[ "${comfyui_manager_enabled,,}" =~ ^(y|yes)$ ]]; then
  msg_info "Install ${application_name} Manager"
  comfyui_manager_dir="${app_path}/custom_nodes/comfyui-manager"
  git clone https://github.com/ltdrdata/ComfyUI-Manager "${comfyui_manager_dir}"
  $STD uv pip install -r "${comfyui_manager_dir}/requirements.txt" --python="${python_path}"
  msg_ok "Installed ${application_name} Manager"
else
  msg_error "No installed ${application_name} Manager"
fi

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/"${application_name}".service
[Unit]
Description=${application_name} Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${app_path}
ExecStart=${python_path} ${app_path}/main.py --listen --port ${port_arg} ${comfyui_python_args}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now "${application_name}"
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
