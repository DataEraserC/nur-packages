#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p nix -p python3

import os
import subprocess
import sys
from pathlib import Path


def run_update(output_file="deps.json", timeout=None):
    """
    标准化的更新函数：构建并运行 fetch-deps 来更新依赖文件。
    """
    script_dir = Path(__file__).parent.absolute()
    project_root = Path(__file__).parent.parent.parent.parent.absolute()

    if output_file == "deps.json":
        output_path = script_dir / output_file
    else:
        output_path = Path(output_file).absolute()

    print(f"正在更新 watt-toolkit 依赖项 -> {output_path}...")

    env = os.environ.copy()
    env["NIXPKGS_ALLOW_BROKEN"] = "1"

    try:
        print("构建 .#watt-toolkit.fetch-deps...")
        build_cmd = ["nix", "build", ".#watt-toolkit.fetch-deps", "--impure"]
        result = subprocess.run(
            build_cmd,
            env=env,
            cwd=project_root,
            text=True,
            timeout=timeout,
        )

        if result.returncode != 0:
            print(f"构建失败，返回码: {result.returncode}")
            return False

        result_link = project_root / "result"
        if not result_link.is_symlink():
            print("错误: 'result' 链接不存在或不是符号链接")
            return False

        script_path = result_link.resolve()

        print(f"执行生成器: {script_path} -> {output_path}")
        run_cmd = [str(script_path), str(output_path)]
        result = subprocess.run(
            run_cmd,
            text=True,
            timeout=timeout,
        )

        if result.returncode != 0:
            print(f"执行失败，返回码: {result.returncode}")
            return False

        print(f"成功更新依赖文件: {output_path}")
        return True

    except subprocess.TimeoutExpired:
        print(f"操作超时 (timeout={timeout}s)")
        return False
    except Exception as e:
        print(f"发生异常: {e}")
        return False


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ["--help", "-h"]:
        print("用法: myupdate.py [输出文件]")
        print("更新 watt-toolkit 的依赖文件 (deps.json)")
        sys.exit(0)

    output_file = sys.argv[1] if len(sys.argv) > 1 else "deps.json"

    success = run_update(output_file)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
