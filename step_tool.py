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
CURRENT_ACCOUNT = ""

def adb(args, account=""):
    try:
        env = os.environ.copy()
        if account:
            env["ACCOUNT"] = account
        r = subprocess.run([ADB, "shell", "sh", SCRIPT] + args,
                           capture_output=True, timeout=30, env=env)
        out = r.stdout.decode("utf-8", errors="replace")
        err = r.stderr.decode("utf-8", errors="replace")
        return out, err, r.returncode
    except Exception as e:
        return "", str(e), -1

def list_accounts():
    # 列出所有账号目录
    r = subprocess.run([ADB, "shell", "ls", "/data/data/com.mi.health/databases/"],
                       capture_output=True, timeout=10)
    out = r.stdout.decode("utf-8", errors="replace")
    accts = []
    for line in out.splitlines():
        line = line.strip()
        if line.isdigit():
            # 检查是否有健身数据库
            r2 = subprocess.run([ADB, "shell", "test", "-f",
                f"/data/data/com.mi.health/databases/{line}/cn/fitness_data"],
                capture_output=True, timeout=5)
            if r2.returncode == 0:
                accts.append(line)
    return accts

def get_steps(account=""):
    out, _, _ = adb(["view"], account)
    acct = ""
    for line in out.splitlines():
        if "数据:" in line:
            parts = line.replace("\\", "/").split("/")
            for i, p in enumerate(parts):
                if p == "databases" and i + 1 < len(parts):
                    acct = parts[i + 1]
                    break
        if "今日步数:" in line:
            for p in line.split():
                if p.isdigit():
                    return int(p), acct
    return None, acct

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

        self.acct_var = tk.StringVar(value="")
        acct_frame = tk.Frame(self.root)
        acct_frame.pack(pady=2)
        tk.Label(acct_frame, text="账号:", font=f).pack(side=tk.LEFT)
        self.acct_combo = ttk.Combobox(acct_frame, textvariable=self.acct_var,
                                        values=[], font=f, width=16, state="readonly")
        self.acct_combo.pack(side=tk.LEFT, padx=5)
        self.acct_combo.bind("<<ComboboxSelected>>", lambda e: self.refresh())

        self.op_var = tk.StringVar(value="set")
        frame = tk.Frame(self.root)
        frame.pack(pady=5)
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
        self.refresh_accts()
        self.refresh()

    def log_append(self, text, tag=None):
        self.log.config(state="normal")
        self.log.insert(tk.END, text + "\n", tag)
        self.log.see(tk.END)
        self.log.config(state="disabled")

    def refresh_accts(self):
        accts = list_accounts()
        self.acct_combo["values"] = accts
        cur = self.acct_var.get()
        if cur not in accts:
            if accts:
                self.acct_var.set(accts[0] if not cur else cur)

    def refresh(self):
        acct = self.acct_var.get()
        s, detected = get_steps(acct)
        if not acct and detected:
            self.acct_var.set(detected)
            acct = detected
        if s is not None:
            self.step_var.set(str(s))
            self.root.title(f"小米运动健康 - 步数修改工具 [账号: {acct or detected}]")
        else:
            self.step_var.set("???")
            self.root.title("小米运动健康 - 步数修改工具")

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
        out, err, code = adb(args, self.acct_var.get())
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
