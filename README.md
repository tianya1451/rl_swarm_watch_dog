

### Introduction

On-chain identity is managed via an Alchemy modal sign-in screen. You need to supply an email address or login via a supported method (e.g. Google). This creates an EOA public/private key (which are stored by Alchemy). You will also receive local session keys in the `userApiKey`. Note that these aren't your EOA public/private keys. 

During the initial set-up process, you will also create a `swarm.pem` file which maintains the identity of your peer. This is then registered on chain using the EOA wallet hosted in Alchemy, triggered using your local api keys. This links the `swarm.pem` to the `email address` (and corresponding EOA in Alchemy).

**If you want to link multiple nodes to a single EOA**, simply sign up each node using the same email address. You will get a new peer ID for each node, however they will all be linked to the same EOA that your email is linked to.

**Please note**: if you are using a fork of this repo, or a service organised by someone else (e.g. a 'one click deployment' provider) the identity management flow below is not guaranteed.

### What this means
In the following two scenarios, everything will work (i.e. you will have an on-chain identity linked with your RL Swarm peer training):

- The very first time you run the node from scratch with a new email address. The smart account will be created fresh and linked with the swarm.pem that is also fresh.
- If you run it again with a `swarm.pem` AND login the original `email address` used with that `swarm.pem`. Note: this will throw an error into the log on registration but will still be able to sign transactions.

In the following two scenarios, it will not work (i.e. you won't have an on-chain identity linked with your RL Swarm peer training):

- If you keep your `swarm.pem` and try to link it to an `email address` distinct from the one with which it was first registered.

Therefore, you should do these actions in the following scenarios

- **Signed up with `email address`, generated `swarm.pem`, BUT lost `swarm.pem`** OR **You want to run multiple nodes at once**: run from scratch with the same email address and generate a new `swarm.pem`. 
- **Signed up with `email address`, generated `swarm.pem`, kept `swarm.pem`** -> you can re-run a single node using this pair if you've still got them both.

## Troubleshooting

- **My peer 'skipped a round'**: this occurs when your device isn't fast enough to keep up with the pace of the swarm. For example, if you start training at round 100 and by the time you finish training the rest of the swarm reaches round 102, you will skip round 101 and go straight to 102. This is because your peer is more valuable if it is participating in the active round.
- **My model doesn't seem to be training?**

    - If you're using a consumer device (e.g. a MacBook), it is likely just running slowly - check back in 20 minutes.

- **Logging in with a new account after previous login?**
    
    - Make sure you click 'Logout' on the login screen before you leave your previous session
    - Make sure you delete `swarm.pem` from the root directory (try `sudo rm swarm.pem`). If you don't do this, and you previously registered with the peer-id stored in this file, it will disrupt the training process.

- **Issues with the Login screen**

    - **Upgrade viem**: some users report issues with the `viem` package. There are two fixes:
        - in the `modal-login/package.json` update: `"viem": "2.25.0"`
        - in the terminal `cd /root/rl-swarm/modal-login/ && yarn upgrade && yarn add next@latest && yarn add viem@latest`

- **I'm getting lots of warnings**
    - This is expected behaviour and usually the output of the package managers or other dependencies. The most common is the below Protobuf warning - which can be ignored
        ```
        WARNING: The candidate selected for download or install is a yanked version: 'protobuf' candidate...
        ```

- **Issues on VMs/VPSs?**

    - **How do I access the login screen if I'm running in a VM?**: port forwarding. Add this SSH flag: `-L 3000:localhost:3000` when connecting to your VM. E.g. `gcloud compute ssh --zone "us-central1-a" [your-vm] --project [your-project] -- -L 3000:localhost:3000`. Note, some VPSs may not work with `rl-swarm`. Check the Gensyn [discord](https://discord.gg/AdnyWNzXh5) for up-to-date information on this.
    
    - **Disconnection/general issues**: If you are tunneling to a VM and suffer a broken pipe, you will likely encounter OOM or unexepected behaviour the first time you relaunch the script. If you `control + c` and kill the script it should spin down all background processes. Restart the script and everything should work normally.

- **Issues with npm/general installation?**

    - Try  `npm install -g node@latest`

- **OOM errors on MacBook?**
    - Try this (experimental) fix to increase memory:
        ```
        export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
        ```
- **I have a Windows machine, can I still train a model on the swarm?**: Yes - but this is not very well tested and may require you to do some debugging to get it set up properly. Install WSL and Linux on your Windows machine using the following instructions: https://learn.microsoft.com/en-us/windows/wsl/install

- **I want to move my to a different machine and/or restart with a fresh build of the repo, but I want my animal name/peer id to persist.**: To achieve this simply backup the `swarm.pem` file on your current machine and then put it in the corresponding location on your new machine/build of the repo.

- **I have multiple GPUs on one machine, can I run multiple peers?**: Yes - but you'll need to manually change things. You'll need to isolate each GPU, install this repo for each GPU, and expose each peer under a different port to pass the modal onboard.

- **My round/stage is behind the smart contract/other peers?**: This is expected behaviour given the different speeds of machines in the network. Once your machine completes it's current round, it will move to the the current round.

- **I want to use a bigger and/or different model in the RL swarm, can I do that?**: Yes - but we only recommend doing so if you are comfortable manually changing files and appropriately configuring the model(s) you wish to run for your device(s). You'll simply need to edit the config file in `./hivemind_exp/configs/<directory_relevant_to_your_device>/grpo-qwen-2.5-0.5b-deepseek-r1.yaml` to reflect the model_name_or_path and training arguments corresponding to what you want in the swarm. Note that, although any pre-trained LLM compatible with Hugging Face's `AutoModelForCausalLM` class should work in theory, we have only tested with a handful of Qwen 2.5 instruction-tuned models.

- **I am running a model in the swarm on my CPU, have received a python `RuntimeError`, and my training progress seems to have stopped.**: There are several possible causes for this, but before trying anything please wait long enough to be sure your training actually is frozen and not just slow (e.g., wait longer than a single training iteration has previously taken on your machine). If you're sure training is actually frozen, then some things to try are:
    - Set this (experimental) fix: `export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0 && ./run_rl_swarm.sh`
    - In the config for your device (`./hivemind_exp/configs/<directory_relevant_to_your_device>/grpo-qwen-2.5-0.5b-deepseek-r1.yaml`) add the following training argument: `max_grad_norm=0.5`
    - Use floating point 32 instead of bfloat16 to train your model. This can be changed in the config for your device, i.e. `./hivemind_exp/configs/<directory_relevant_to_your_device>/grpo-qwen-2.5-0.5b-deepseek-r1.yaml`.

- **How can I optimsie `rl-swarm` for my device**? open the `hivemind_exp/configs/gpu/grpo-qwen-2.5-0.5b-deepseek-r1.yaml`. Note that this is for the gpu and not cpu configuration. You can then edit parameters that optimsie the training run. For example, try adjusting the `vllm_gpu_memory_utilization`. Note that optimal settings will vary by device.

# RL-Swarm 监控脚本 | RL-Swarm Monitoring Script

## 简介 | Introduction

这是一个用于监控和管理RL-Swarm程序的守护脚本，可以自动检测程序状态、处理错误并在需要时重启程序。

This is a daemon script for monitoring and managing the RL-Swarm program, which automatically detects program status, handles errors, and restarts the program when necessary.

## 功能 | Features

### 中文版

1. **自动启动与重启**：
   - 自动启动RL-Swarm程序并提供默认参数
   - 在检测到异常时自动重启程序

2. **多重监控机制**：
   - 通过进程检查监控Hivemind服务状态
   - 实时监控日志文件中的特定错误（如P2PDaemonError）
   - 通过识别进度条信息判断程序运行状态

3. **日志管理**：
   - 定期清空主程序日志，防止重复检测错误
   - 每15秒显示最新3条程序日志
   - 将监控信息记录到专用日志文件

4. **健壮性设计**：
   - 在启动前检查网络连接
   - 采用信号机制触发紧急重启
   - 优雅关闭所有监控进程

5. **智能判断**：
   - 通过识别标准进度条格式判断程序正常运行
   - 自动响应特定错误模式

### English Version

1. **Automatic Startup and Restart**:
   - Automatically starts the RL-Swarm program with default parameters
   - Restarts the program when anomalies are detected

2. **Multiple Monitoring Mechanisms**:
   - Monitors Hivemind service status through process checks
   - Real-time monitoring of specific errors in log files (e.g., P2PDaemonError)
   - Determines program running status by recognizing progress bar information

3. **Log Management**:
   - Periodically clears the main program logs to prevent repeat error detection
   - Displays the latest 3 program log entries every 15 seconds
   - Records monitoring information to a dedicated log file

4. **Robust Design**:
   - Checks network connectivity before startup
   - Uses signal mechanisms to trigger emergency restarts
   - Gracefully closes all monitoring processes

5. **Intelligent Judgment**:
   - Determines normal program operation by identifying standard progress bar formats
   - Automatically responds to specific error patterns

## 安装 | Installation

### 中文版

1. 下载监控脚本到您的工作目录：
   ```bash
   curl -o monitor_rl_swarm.sh https://raw.githubusercontent.com/yourusername/rl-swarm/main/monitor_rl_swarm.sh
   ```

2. 赋予脚本执行权限：
   ```bash
   chmod +x monitor_rl_swarm.sh
   ```

3. 根据您的环境修改脚本中的路径和设置（如需要）。

### English Version

1. Download the monitoring script to your working directory:
   ```bash
   curl -o monitor_rl_swarm.sh https://raw.githubusercontent.com/yourusername/rl-swarm/main/monitor_rl_swarm.sh
   ```

2. Grant execution permissions to the script:
   ```bash
   chmod +x monitor_rl_swarm.sh
   ```

3. Modify the paths and settings in the script according to your environment (if necessary).

## 使用方法 | Usage

### 中文版

1. 启动监控脚本：
   ```bash
   ./monitor_rl_swarm.sh
   ```

2. 建议在后台运行或使用screen/tmux会话：
   ```bash
   nohup ./monitor_rl_swarm.sh > nohup.out 2>&1 &
   ```
   或
   ```bash
   screen -S rl-swarm
   ./monitor_rl_swarm.sh
   # 按 Ctrl+A 然后按 D 分离会话
   ```

3. 查看监控日志：
   ```bash
   tail -f monitor.log
   ```

### English Version

1. Start the monitoring script:
   ```bash
   ./monitor_rl_swarm.sh
   ```

2. Recommended to run in background or use screen/tmux sessions:
   ```bash
   nohup ./monitor_rl_swarm.sh > nohup.out 2>&1 &
   ```
   or
   ```bash
   screen -S rl-swarm
   ./monitor_rl_swarm.sh
   # Press Ctrl+A then D to detach the session
   ```

3. View monitoring logs:
   ```bash
   tail -f monitor.log
   ```

## 配置 | Configuration

### 中文版

脚本顶部包含可自定义的配置参数：

- `LOG_FILE`：监控日志文件路径
- `WORKSPACE`：RL-Swarm工作目录路径

您可以根据需要修改这些变量以适应您的环境。

### English Version

The script contains customizable configuration parameters at the top:

- `LOG_FILE`: Path to the monitoring log file
- `WORKSPACE`: Path to the RL-Swarm working directory

You can modify these variables as needed to suit your environment.

## 故障排除 | Troubleshooting

### 中文版

1. **问题**：脚本无法启动RL-Swarm程序
   **解决方案**：检查工作目录路径和run_rl_swarm.sh脚本是否存在

2. **问题**：监控脚本反复重启程序
   **解决方案**：检查日志文件中的错误信息，可能需要调整错误检测逻辑

3. **问题**：网络连接检查失败
   **解决方案**：确认您的网络连接状态或修改check_network函数中的检测URL

### English Version

1. **Problem**: Script fails to start the RL-Swarm program
   **Solution**: Check if the working directory path and run_rl_swarm.sh script exist

2. **Problem**: Monitoring script repeatedly restarts the program
   **Solution**: Check error messages in the log files; you may need to adjust the error detection logic

3. **Problem**: Network connection check fails
   **Solution**: Verify your network connection status or modify the detection URL in the check_network function
