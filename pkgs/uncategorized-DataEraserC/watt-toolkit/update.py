#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p nix -p python3

import os
import subprocess
import sys
from pathlib import Path

def run_update(output_file="deps.json"):
    """
    标准化的更新函数：构建并运行 fetch-deps 来更新依赖文件。
    """
    # 获取脚本所在目录作为项目根目录
    script_dir = Path(__file__).parent.absolute()
    project_root = Path(__file__).parent.parent.parent.parent.absolute()
    
    # 确保输出文件在正确的路径
    if output_file == "deps.json":
        output_path = script_dir / output_file
    else:
        output_path = Path(output_file).absolute()

    print(f"正在更新 watt-toolkit 依赖项 -> {output_path}...")

    # 设置环境变量
    env = os.environ.copy()
    env["NIXPKGS_ALLOW_BROKEN"] = "1"

    try:
        # Step 1: 构建 fetch-deps
        print("构建 .#watt-toolkit.fetch-deps...")
        build_cmd = ["nix", "build", ".#watt-toolkit.fetch-deps", "--impure"]
        result = subprocess.run(build_cmd, env=env, cwd=project_root, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"构建失败: {result.stderr}")
            return False

        # Step 2: 运行结果程序以生成 deps.json
        result_link = project_root / "result"
        if not result_link.is_symlink():
            print("错误: 'result' 链接不存在或不是符号链接")
            return False

        target_script = os.readlink(result_link)
        script_path = project_root / target_script

        print(f"执行生成器: {script_path} -> {output_path}")
        run_cmd = [str(script_path), str(output_path)]
        result = subprocess.run(run_cmd, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"执行失败: {result.stderr}")
            return False

        print(f"成功更新依赖文件: {output_path}")
        return True

    except Exception as e:
        print(f"发生异常: {e}")
        return False

def main():
    if len(sys.argv) > 1 and sys.argv[1] in ["--help", "-h"]:
        print("用法: update.py [输出文件]")
        print("更新 watt-toolkit 的依赖文件 (deps.json)")
        sys.exit(0)

    # 可选：接受输出路径作为第一个参数
    output_file = sys.argv[1] if len(sys.argv) > 1 else "deps.json"

    success = run_update(output_file)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()