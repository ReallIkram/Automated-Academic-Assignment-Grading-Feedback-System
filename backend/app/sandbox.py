import base64, time
import docker

IMAGES={'python':'gradeflow-python:local','java':'gradeflow-java:local','cpp':'gradeflow-cpp:local'}
FILES={'python':'main.py','java':'Main.java','cpp':'main.cpp'}
COMMANDS={'python':'python -I /work/main.py < /work/input.txt', 'java':'javac -d /tmp /work/Main.java && java -Xmx128m -XX:ActiveProcessorCount=1 -cp /tmp Main < /work/input.txt','cpp':'g++ -O0 /work/main.cpp -o /tmp/main && /tmp/main < /work/input.txt'}

def run_case(code,language,stdin,timeout=5):
 client=docker.from_env(); container=None; start=time.monotonic()
 try:
  # Source enters by archive; host paths and credentials are never mounted.
  source=base64.b64encode(code.encode()).decode(); input_data=base64.b64encode(stdin.encode()).decode()
  command=f"umask 077; printf '%s' '{source}' | base64 -d > /work/{FILES[language]}; printf '%s' '{input_data}' | base64 -d > /work/input.txt; ulimit -f 128; ulimit -t 5; ( {COMMANDS[language]} ) > /tmp/out 2> /tmp/err; status=$?; cat /tmp/out; cat /tmp/err >&2; exit $status"
  container=client.containers.create(IMAGES[language],['sh','-c',command],network_disabled=True,mem_limit='256m',memswap_limit='256m',nano_cpus=1_000_000_000,pids_limit=64,read_only=True,user='65534:65534',cap_drop=['ALL'],security_opt=['no-new-privileges:true'],tmpfs={'/work':'rw,noexec,nosuid,size=2m','/tmp':'rw,noexec,nosuid,size=64m' if language!='cpp' else 'rw,nosuid,size=64m'},working_dir='/work',log_config=docker.types.LogConfig(type='json-file',config={'max-size':'1m','max-file':'1'}))
  container.start()
  try: result=container.wait(timeout=timeout); exit_code=result['StatusCode']
  except Exception:
   container.kill(); return {'stdout':'','stderr':'Time limit exceeded','exit_code':-1,'seconds':timeout}
  return {'stdout':container.logs(stdout=True,stderr=False).decode(errors='replace')[:65536], 'stderr':container.logs(stdout=False,stderr=True).decode(errors='replace')[:65536], 'exit_code':exit_code,'seconds':round(time.monotonic()-start,3)}
 finally:
  if container is not None: container.remove(force=True)
  client.close()
