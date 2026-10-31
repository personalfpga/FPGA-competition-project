"""Redact local account paths in text artifacts without changing data values."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
def sanitize_text(text):
    for value in (str(ROOT),ROOT.as_posix()):
        text=text.replace(value,'<PROJECT_ROOT>')
    text=re.sub(r'(?i)[a-z]:[/\\]+Users[/\\]+[^/\\\s<>"|]+[/\\]+Documents[/\\]+Codex','<WORKSPACE>',text)
    text=re.sub(r'(?i)[a-z]:[/\\]+Users[/\\]+[^/\\\s<>"|]+','<USER_HOME>',text)
    text=re.sub(r'wxid_[A-Za-z0-9_]+','<WECHAT_USER>',text)
    return text
