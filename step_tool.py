import subprocess, os, sys, tkinter as tk
from tkinter import messagebox

# ---------- 自动检测 adb ----------
def find_adb():
    # 优先 PATH 中的 adb
    for p in os.environ.get("PATH", "").split(";"):
        exe = os.path.join(p, "adb.exe")
        if os.path.isfile(exe):
            return exe
    # 常见安装路径
    candidates = [
        r"C:\Program Files\platform-tools\adb.exe",
        r"C:\Program Files (x86)\platform-tools\adb.exe",
        r"D:\Program Files\platform-tools\adb.exe",
        r"C:\Android\sdk\platform-tools\adb.exe",
        r"D:\Android\sdk\platform-tools\adb.exe",
        os.path.expanduser(r"~\AppData\Local\Android\Sdk\platform-tools\adb.exe"),
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None

ADB = find_adb()
if not ADB:
    tk.Tk().withdraw()
    messagebox.showerror("错误", "未找到 adb.exe，请安装 Android platform-tools 并添加到 PATH")
    sys.exit(1)

SCRIPT = "/sdcard/stepmod.sh"

def adb(args):
    try:
        r = subprocess.run([ADB, "shell", "sh", SCRIPT] + args,
                           capture_output=True, timeout=30)
        out = r.stdout.decode("utf-8", errors="replace")
        err = r.stderr.decode("utf-8", errors="replace")
        return out, err, r.returncode
    except Exception as e:
        return "", str(e), -1

def get_steps():
    out, _, _ = adb(["view"])
    for line in out.splitlines():
        if "今日步数:" in line:
            for p in line.split():
                if p.isdigit():
                    return int(p)
    return None

class App:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("小米运动健康 - 步数修改工具")
        self.root.geometry("460x420")
        self.root.resizable(False, False)
        f = ("Microsoft YaHei UI", 10)
        tk.Label(self.root, text="小米运动健康步数修改",
                 font=("Microsoft YaHei UI", 14, "bold")).pack(pady=(12, 5))

        self.step_var = tk.StringVar(value="---")
        self.step_lb = tk.Label(self.root, textvariable=self.step_var,
                                font=("Microsoft YaHei UI", 22, "bold"), fg="#E53935")
        self.step_lb.pack()
        tk.Label(self.root, text="当前步数", font=f, fg="gray").pack()

        self.op_var = tk.StringVar(value="set")
        frame = tk.Frame(self.root)
        frame.pack(pady=10)
        for t, v in [("增加", "add"), ("减少", "sub"), ("指定", "set"), ("清零", "clear")]:
            tk.Radiobutton(frame, text=t, variable=self.op_var, value=v, font=f).pack(side=tk.LEFT, padx=5)

        tk.Label(self.root, text="步数:", font=f).pack()
        self.val_entry = tk.Entry(self.root, font=("Microsoft YaHei UI", 12), width=18, justify="center")
        self.val_entry.pack(pady=2)
        self.val_entry.insert(0, "10000")

        tk.Button(self.root, text="执行修改",
                  font=("Microsoft YaHei UI", 11, "bold"),
                  bg="#4CAF50", fg="white", padx=20, pady=4,
                  command=self.do_mod).pack(pady=8)

        self.log = tk.Text(self.root, height=8, width=55, font=("Consolas", 9), state="disabled")
        self.log.pack(pady=5)
        self.log.tag_config("ok", foreground="green")
        self.log.tag_config("err", foreground="red")

        tk.Button(self.root, text="刷新步数", font=f, command=self.refresh).pack(pady=2)
        self.refresh()

    def log_append(self, text, tag=None):
        self.log.config(state="normal")
        self.log.insert(tk.END, text + "\n", tag)
        self.log.see(tk.END)
        self.log.config(state="disabled")

    def refresh(self):
        s = get_steps()
        if s is not None:
            self.step_var.set(str(s))
        else:
            self.step_var.set("???")

    def do_mod(self):
        op = self.op_var.get()
        val = self.val_entry.get().strip()
        if op == "clear":
            args = ["clear"]
            self.log_append(">> 清零...", "ok")
        else:
            if not val.isdigit():
                messagebox.showerror("错误", "请输入有效数字")
                return
            args = [op, val]
            self.log_append(f">> {op} {val}...", "ok")
        out, err, code = adb(args)
        for line in out.splitlines():
            self.log_append(line)
        if err.strip():
            self.log_append("ERR: " + err.strip(), "err")
        if "验证步数:" in out:
            for line in out.splitlines():
                if "验证步数:" in line:
                    for p in line.split():
                        if p.isdigit():
                            self.step_var.set(p)
                            break
        else:
            self.refresh()

    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    App().run()
