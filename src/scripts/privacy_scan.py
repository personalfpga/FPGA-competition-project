from pathlib import Path
import re,json,sys,zipfile,io
root=Path(__file__).resolve().parents[2]
issues=[]
def check_container(blob,label):
    if not blob.startswith(b'PK'+bytes([3,4])):return
    with zipfile.ZipFile(io.BytesIO(blob)) as archive:
        for name in archive.namelist():
            if name.endswith('/'):continue
            content=archive.read(name)
            if re.search(rb'(?i)[a-z]:[/\\]+users[/\\]+|/' + b'home/',content):issues.append([label+'::'+name,'container_privacy'])
            try:text=content.decode('utf-8-sig')
            except UnicodeDecodeError:continue
            if re.search('[\u3400-\u9fff]',text):issues.append([label+'::'+name,'container_han'])

han=re.compile('[\u3400-\u9fff\uf900-\ufaff]')
patterns=[re.compile(x) for x in [r'[\w.%+\-]+@[\w.\-]+\.[A-Za-z]{2,}',r'(?i)[a-z]:[/\\]+users[/\\]+',r'/' + 'home' + r'/',r'(?<![A-Za-z0-9])1[3-9][0-9]{9}(?![A-Za-z0-9])']]
for f in root.rglob('*'):
    p=f.relative_to(root).as_posix()
    if not re.fullmatch('[a-z0-9_./-]+',p):issues.append([p,'name'])
    if not f.is_file():continue
    if f.stat().st_size>100000000:issues.append([p,'size'])
    b=f.read_bytes()
    check_container(b,p)
    try:t=b.decode('utf-8-sig')
    except UnicodeDecodeError:
        t='\n'.join(x.decode('ascii') for x in re.findall(rb'[ -~]{6,}',b))
    if han.search(t) and not p.startswith('ai_records/'):issues.append([p,'han'])
    for term in [chr(x) for x in []]:pass
    affiliation = '|'.join(''.join(chr(v) for v in codes) for codes in [(23398,26657),(22823,23398),(23398,38498),(32769,24072),(25351,23548)])
    if re.search(affiliation,t):issues.append([p,'affiliation_term'])
    for pat in patterns:
        if pat.search(t):issues.append([p,'privacy'])
print(json.dumps({'findings':len(issues),'issues':issues},indent=2))
sys.exit(bool(issues))
