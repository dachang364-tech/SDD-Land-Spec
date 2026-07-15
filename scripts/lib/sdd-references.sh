#!/usr/bin/env bash
_sdd_refs_python() {
python3 - "$@" <<'PY'
import json,re,sys
from pathlib import Path
H=["关系","当前范围","目标文档","目标标识","说明"]; E=["未声明。","-","-","-","-"]
R={"references","derives_from","implements","modifies","replaces","deprecates"}; S={"modifies","replaces","deprecates"}
K=("依据","来源","派生","修改","替代","决策","实现","implements","modifies","replaces","derives_from")
L=re.compile(r"\[([^\]]+)\]\(([^)]+)\)"); V=re.compile(r"^(v\d+\.\d+\.\d+):(.+\.md)$"); P=re.compile(r"^project:(requirements/.+\.md)$")
A={"requirements":{"requirements"},"prd":{"requirements","prd","spec","dr"},"spec":{"prd","requirements","dr","spec"},"plan":{"spec","dr","plan"},"dr":{"requirements","prd","spec","plan","dr"}}
def relative(root,p):
 try:return Path(p).resolve().relative_to(Path(root).resolve()).as_posix()
 except ValueError:return str(Path(p).resolve())
def kind(p):
 p=Path(p).as_posix()
 if "docs/requirements/" in p:return "requirements"
 if p.endswith("/prd.md"):return "prd"
 if "/specs/" in p:return "spec"
 if "/plans/" in p:return "plan"
 if "/decisions/" in p:return "dr"
 if p.endswith("/ARCHIVE.md"):return "archive"
 if p.endswith("/archive/INDEX.md"):return "index"
 return "other"
def cells(line):return [x.strip() for x in line.strip()[1:-1].split("|")] if line.strip().startswith("|") and line.strip().endswith("|") else None
def table(text):
 lines=text.splitlines(); start=next((i for i,x in enumerate(lines) if x.strip()=="## 文档引用"),None)
 if start is None:raise ValueError("missing_reference_table")
 raw=[]
 for x in lines[start+1:]:
  if x.startswith("## "):break
  if x.strip().startswith("|"):raw.append(x)
  elif raw and x.strip():break
 if len(raw)<3 or cells(raw[0])!=H or len(cells(raw[1]) or [])!=5:raise ValueError("invalid_reference_header")
 rows=[cells(x) for x in raw[2:]]
 if any(x is None or len(x)!=5 for x in rows):raise ValueError("invalid_reference_row")
 if rows==[E]:rows=[]
 elif E in rows:raise ValueError("empty_row_mixed_with_data")
 return rows,(start,start+len(raw))
def resolve(root,source,original):
 raw=original.split("#",1)[0]
 if not raw or original.startswith("#") or re.match(r"^[A-Za-z][\w+.-]*://",original) or not raw.lower().endswith(".md"):return "skip",""
 p=(Path(source).resolve().parent/raw).resolve()
 try:p.relative_to((Path(root)/"docs").resolve())
 except ValueError:return "unsafe",str(p)
 return "local",p
def locator(root,s):
 m=V.fullmatch(s)
 if m:return (Path(root)/"docs/versions"/m.group(1)/m.group(2)).resolve()
 m=P.fullmatch(s)
 return (Path(root)/"docs"/m.group(1)).resolve() if m else None
def parse(root,source):
 text=Path(source).read_text(encoding="utf-8"); rows,region=table(text); out=[]
 for relation,scope,target,loc,note in rows:
  m=L.fullmatch(target); original=m.group(2) if m else ""; rk,res=resolve(root,source,original) if m else ("invalid","")
  out.append(dict(source=relative(root,source),relation=relation,scope=scope,target_markdown=target,link_text=m.group(1) if m else "",original=original,locator=loc,note=note,resolved=relative(root,res) if rk=="local" else str(res or ""),resolution_kind=rk,source_type=kind(relative(root,source)),target_type=kind(relative(root,res)) if res else "other"))
 return out,text,region
def diag(level,code,source,original="",resolved="",reason=""):return dict(level=level,code=code,source=source,original=original,resolved=resolved,reason=reason)
def validate(root,source):
 sr=relative(root,source); out=[]
 try:rows,text,region=parse(root,source)
 except ValueError as e:return [diag("blocking",str(e),sr,reason="reference table must use exact five-column contract")]
 declared=set()
 for x in rows:
  rel,loc,original,res,rk=x["relation"],x["locator"],x["original"],x["resolved"],x["resolution_kind"]
  if rel not in R:out.append(diag("blocking","invalid_relation",sr,original,res,"relation outside enum"))
  if not x["link_text"]:out.append(diag("blocking","target_not_markdown_link",sr,reason="目标文档 must be Markdown link"));continue
  if rk=="unsafe":out.append(diag("blocking","unsafe_path",sr,original,res,"normalized path escapes project root"));continue
  if rk=="skip":continue
  declared.add(res); rp=(Path(root)/res).resolve()
  if not rp.is_file():out.append(diag("blocking","missing_target",sr,original,res,"local Markdown target does not exist"))
  sv=next((p for p in Path(sr).parts if re.fullmatch(r"v\d+\.\d+\.\d+",p)),None); tv=next((p for p in Path(res).parts if re.fullmatch(r"v\d+\.\d+\.\d+",p)),None)
  cross=bool(sv and tv and sv!=tv); project=res.startswith("docs/requirements/")
  if cross and not V.fullmatch(loc):out.append(diag("blocking","missing_version_locator",sr,original,res,"cross-version locator required"))
  if project and not P.fullmatch(loc):out.append(diag("blocking","missing_project_locator",sr,original,res,"project locator required"))
  if loc!="-":
   lp=locator(root,loc)
   if lp is None:out.append(diag("blocking","invalid_locator",sr,original,res,"invalid locator format"))
   elif lp!=rp:out.append(diag("blocking","locator_mismatch",sr,original,res,"link and locator differ"))
   elif not cross and not project:out.append(diag("warning","same_version_locator",sr,original,res,"same-version locator is unnecessary"))
  if x["source_type"]=="plan" and rel in S:out.append(diag("blocking","plan_strong_relation",sr,original,res,"plan cannot use strong relation"))
  if x["target_type"] not in A.get(x["source_type"],set()):
   if rel in S:out.append(diag("blocking","direction_matrix_strong",sr,original,res,"matrix-external strong relation"))
   elif rel=="references" and x["note"].strip():out.append(diag("warning","direction_matrix_weak",sr,original,res,"matrix-external weak relation"))
  compact=re.sub(r"\s+","",x["note"]); words=re.findall(r"[A-Za-z]+",x["note"])
  if compact in {"参考","相关","见上","N/A","-"} or (re.search(r"[\u4e00-\u9fff]",compact) and len(compact)<6) or (not re.search(r"[\u4e00-\u9fff]",compact) and len(words)<3):out.append(diag("warning","short_note",sr,original,res,"note too short or placeholder"))
 lines=text.splitlines(); a,b=region; body="\n".join(lines[:a]+lines[b+1:])
 for line in body.splitlines():
  if any(k in line for k in K):
   for _,original in L.findall(line):
    rk,res=resolve(root,source,original); rr=relative(root,res) if rk=="local" else ""
    if rk=="local" and rr not in declared:out.append(diag("warning","body_link_not_declared",sr,original,rr,"keyword-bearing body link absent from table"))
 return out
def files(v):
 p=Path(v); out=([p/"prd.md"] if (p/"prd.md").is_file() else [])
 for d in ("specs","plans","decisions"):out+=sorted((p/d).glob("*.md"))
 return out
def extract(root,v,cross_file,strong_file):
 cross=[];strong=[];bad=False;version=Path(v).name
 for source in files(v):
  try:rows,_,_=parse(root,source)
  except ValueError:bad=True;continue
  for x in rows:
   display=Path(x["source"]).relative_to(Path("docs/versions")/version).as_posix()
   if V.fullmatch(x["locator"]) or P.fullmatch(x["locator"]):cross.append(f'| {display} | {x["relation"]} | {x["target_markdown"]} | {x["locator"]} | {x["note"]} |')
   elif x["relation"] in S:strong.append(f'| {display} | {x["relation"]} | {x["target_markdown"]} | {x["note"]} |')
 if bad:
  cross=cross or ["| 未能机械提取；请查看原始文档。 | - | - | - | - |"]
  strong=strong or ["| 未能机械提取；请查看原始文档。 | - | - | - |"]
 Path(cross_file).write_text("\n".join(cross or ["| 未发现。 | - | - | - | - |"]) + "\n",encoding="utf-8")
 Path(strong_file).write_text("\n".join(strong or ["| 未发现。 | - | - | - |"])+"\n",encoding="utf-8")
cmd=sys.argv[1]
if cmd=="parse-table":
 source=Path(sys.argv[2]).resolve(); root=next((p for p in source.parents if (p/"docs").is_dir()),Path.cwd())
 rows,_,_=parse(root,source)
 for x in rows:x.pop("resolution_kind",None);print(json.dumps(x,ensure_ascii=False,sort_keys=True))
elif cmd=="validate":
 ds=validate(Path(sys.argv[2]).resolve(),Path(sys.argv[3]).resolve())
 for x in ds:print(json.dumps(x,ensure_ascii=False,sort_keys=True))
 if any(x["level"]=="blocking" for x in ds):sys.exit(2)
elif cmd=="extract-archive":extract(Path(sys.argv[2]).resolve(),Path(sys.argv[3]).resolve(),sys.argv[4],sys.argv[5])
else:print("usage: sdd-references.sh parse-table|validate|extract-archive ...",file=sys.stderr);sys.exit(64)
PY
}
sdd_refs_parse_table(){ _sdd_refs_python parse-table "$1"; }
sdd_refs_validate(){ _sdd_refs_python validate "$1" "$2"; }
sdd_refs_extract_archive(){ _sdd_refs_python extract-archive "$1" "$2" "$3" "$4"; }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then _sdd_refs_python "$@"; fi
