#!/usr/bin/env python3
# 已合并进 gen_site.py（官网首页 / 支持页 / 隐私与条款一起生成）。保留这个入口，老命令照样能用。
import pathlib
import runpy

runpy.run_path(str(pathlib.Path(__file__).with_name("gen_site.py")), run_name="__main__")
