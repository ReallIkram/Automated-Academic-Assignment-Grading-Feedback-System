"""Run after flutter create to enable macOS outgoing API requests."""
from pathlib import Path
import plistlib
root=Path(__file__).resolve().parents[1]/'flutter_app'
for name in ('DebugProfile.entitlements','Release.entitlements'):
 path=root/'macos'/'Runner'/name
 if path.exists():
  with path.open('rb') as stream: data=plistlib.load(stream)
  data['com.apple.security.network.client']=True
  with path.open('wb') as stream: plistlib.dump(data,stream)
print('Platform configuration complete. Use HTTPS for remote release APIs.')
