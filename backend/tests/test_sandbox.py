import os
import pytest
from app.sandbox import run_case
pytestmark=pytest.mark.skipif(os.getenv('RUN_DOCKER_TESTS')!='1',reason='Requires Docker and the three built sandbox images')
@pytest.mark.parametrize('language,code',[('python','a,b=map(int,input().split());print(a+b)'),('java','import java.util.Scanner; public class Main { public static void main(String[] a){Scanner s=new Scanner(System.in);System.out.println(s.nextInt()+s.nextInt());}}'),('cpp','#include <iostream>\nint main(){int a,b;std::cin>>a>>b;std::cout<<a+b;}')])
def test_real_execution(language,code):
 r=run_case(code,language,'2 3');assert r['exit_code']==0,r;assert r['stdout'].strip()=='5'
def test_timeout():
 r=run_case('while True: pass','python','',timeout=2);assert r['exit_code']!=0
def test_network_blocked():
 r=run_case('import socket\nsocket.create_connection(("1.1.1.1",80),timeout=1)','python','');assert r['exit_code']!=0
