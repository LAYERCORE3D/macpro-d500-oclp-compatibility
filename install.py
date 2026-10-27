#!/usr/bin/python3
"""Narrow, reversible experimental installation. Default: read-only preflight.
Only --apply or --rollback write a system volume. Never reboots automatically.
"""
import argparse,datetime,hashlib,json,os,plistlib,re,shutil,subprocess,sys,tempfile
from pathlib import Path
PACKAGE=Path(__file__).resolve().parent
BUNDLE=Path('System/Library/Extensions/AMDMTLBronzeDriver.bundle')
STATE=Path('/Library/Application Support/D500Official205')
MOUNT=Path('/System/Volumes/Update/D500Official205')

def receipt(status,**extra):
    # Public diagnostic metadata only; credentials and backup contents never enter it.
    record={'status':status,'time':datetime.datetime.now().isoformat(),**extra}
    with tempfile.NamedTemporaryFile(mode='w',dir=PACKAGE,prefix='.receipt-',delete=False) as f:
        json.dump(record,f,indent=2);name=f.name
    os.chmod(name,0o644);os.replace(name,PACKAGE/'status-public.json')

def run(args,**kwargs):
    return subprocess.run([str(x) for x in args],check=True,**kwargs)
def output(args):return run(args,stdout=subprocess.PIPE).stdout
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def tree(p):return {str(f.relative_to(p)):sha(f) for f in p.rglob('*') if f.is_file()}
def verify(p,expected):
    if tree(p)!=expected:raise RuntimeError('Los archivos no coinciden con el manifiesto: '+str(p))
def system_info():
    version=plistlib.loads(Path('/System/Library/CoreServices/SystemVersion.plist').read_bytes())
    if output(['/usr/sbin/sysctl','-n','hw.model']).decode().strip()!='MacPro6,1':raise RuntimeError('Mac diferente al probado')
    if (version['ProductVersion'],version['ProductBuildVersion'])!=('15.8.1','24H32'):raise RuntimeError('Versión de macOS diferente a la probada')
    d=plistlib.loads(output(['/usr/sbin/diskutil','info','-plist','/']))
    if not d.get('APFSSnapshot') or not d.get('Internal') or d.get('FileVault'):raise RuntimeError('Disposición de disco no probada')
    match=re.fullmatch(r'(disk\d+s\d+)s\d+',d['DeviceIdentifier'])
    if not match:raise RuntimeError('No se identifica con seguridad el volumen APFS de sistema')
    return d,'/dev/'+match.group(1)
def validate_signatures(bundle):
    # The official release has a stale nested resource seal. Its exact released
    # bytes are pinned in the manifest; separately verify both executable signatures.
    # Never sign or rewrite any file in the bundle.
    for name in ('impostor.dylib', 'AMDMTLBronzeDriver'):
        run(['/usr/bin/codesign','--verify','--ignore-resources','-R',
             '=certificate root = H"c290d2bff240f4e990f7ac9b632f568d0e2a82f5"',
             bundle/'Contents/MacOS'/name])

def validate_payload():
    manifest=json.loads((PACKAGE/'manifest.json').read_text())
    verify(PACKAGE/BUNDLE.name,manifest['bundleFiles'])
    validate_signatures(PACKAGE/BUNDLE.name)
    return manifest

def perform(mode):
    if mode=='apply' and (PACKAGE/'RETIRADO-POR-FALLO-DE-ARRANQUE.txt').exists():
        raise RuntimeError('Instalador retirado: fallo de firma del controlador en WindowServer. No aplicar.')
    d,device=system_info();manifest=validate_payload()
    current=Path('/')/BUNDLE
    if mode in ('check','apply') and sha(current/'Contents/MacOS/impostor.dylib')!=manifest['sourceSha256']:
        raise RuntimeError('El adaptador instalado ha cambiado; no se aplica encima de otra versión')
    print('Equipo, macOS, firma y contenido del candidato: comprobados.',flush=True)
    print('Snapshot de arranque actual: '+d['APFSSnapshotUUID'],flush=True)
    if mode=='check':
        print('Solo comprobación. No se ha cambiado el sistema.');return
    if os.geteuid()!=0:raise RuntimeError('Se necesita autenticación de administrador en Terminal')
    receipt('in-progress',mode=mode)
    if MOUNT.is_symlink() or os.path.ismount(MOUNT):raise RuntimeError('Punto de montaje ocupado o no válido')
    STATE.mkdir(parents=True,exist_ok=True);os.chmod(STATE,0o700)
    if mode=='apply':
        stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        work=STATE/('backup-'+stamp);work.mkdir(mode=0o700)
        run(['/usr/bin/ditto',current,work/BUNDLE.name])
        before=tree(work/BUNDLE.name)
        if before!=tree(current):raise RuntimeError('No se pudo verificar el respaldo completo')
        state={'originalBootSnapshot':d['APFSSnapshotUUID'],'device':device,'originalFiles':before,'candidateFiles':manifest['bundleFiles'],'committed':False}
        (work/'state.json').write_text(json.dumps(state,indent=2))
    else:
        choices=sorted(STATE.glob('backup-*/state.json'),reverse=True)
        active=[p for p in choices if json.loads(p.read_text()).get('committed') and not json.loads(p.read_text()).get('rolledBack')]
        if not active:raise RuntimeError('No existe instalación activa con respaldo verificado')
        work=active[0].parent;state=json.loads(active[0].read_text())
        verify(work/BUNDLE.name,state['originalFiles'])
        if tree(current) not in (state['originalFiles'],state['candidateFiles']):
            raise RuntimeError('El controlador activo no coincide con el original ni el candidato')
    MOUNT.mkdir(exist_ok=True)
    mounted=False;changed=False;committed=False
    try:
        run(['/sbin/mount','-o','nobrowse','-t','apfs',device,MOUNT]);mounted=True
        v=plistlib.loads((MOUNT/'System/Library/CoreServices/SystemVersion.plist').read_bytes())
        if v['ProductBuildVersion']!='24H32':raise RuntimeError('El volumen montado tiene otra versión')
        target=MOUNT/BUNDLE
        verify(target,state['originalFiles'] if mode=='apply' else state['candidateFiles'])
        source=PACKAGE/BUNDLE.name if mode=='apply' else work/BUNDLE.name
        expected=state['candidateFiles'] if mode=='apply' else state['originalFiles']
        staged=target.with_name('.D500Official205-stage-'+str(os.getpid()))
        if staged.exists():raise RuntimeError('Existe un área de preparación inesperada')
        # A previous failed attempt may have left a verified staging bundle.
        # Never remove an unknown directory or a symlink.
        for leftover in target.parent.glob('.D500Official205-stage-*'):
            if leftover.is_symlink():raise RuntimeError('Área temporal no válida')
            verify(leftover,state['candidateFiles']);shutil.rmtree(leftover)
        # diskutil on this macOS has no "snapshot" verb. Use the same documented
        # bless snapshot creation mechanism as OCLP, before altering the bundle.
        if mode=='apply':
            result=run(['/usr/sbin/bless','--folder',MOUNT/'System/Library/CoreServices','--bootefi','--create-snapshot'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
            state['preChangeSnapshotMethod']='bless --create-snapshot'
            state['preChangeSnapshotOutput']=result.stdout.decode(errors='replace')
            (work/'state.json').write_text(json.dumps(state,indent=2))
            print('Snapshot previo creado con bless.',flush=True)
        run(['/usr/bin/ditto',source,staged]);verify(staged,expected)
        validate_signatures(staged)
        previous=target.with_name('.D500Official205-previous-'+str(os.getpid()))
        if previous.exists():raise RuntimeError('Existe una copia temporal inesperada')
        os.rename(target,previous)
        try:os.rename(staged,target)
        except BaseException:
            os.rename(previous,target);raise
        changed=True
        run(['/usr/sbin/chown','-R','root:wheel',target])
        verify(target,expected)
        # Only a user-space driver bundle changes; no kext or KernelCollection is modified.
        run(['/usr/sbin/bless','--folder',MOUNT/'System/Library/CoreServices','--bootefi','--create-snapshot'])
        committed=True
        receipt('snapshot-selected',mode=mode,backup=str(work),requiresReboot=True)
        shutil.rmtree(previous)
        if mode=='apply':state['committed']=True
        else:state['rolledBack']=True
        (work/'state.json').write_text(json.dumps(state,indent=2))
        receipt('prepared',mode=mode,backup=str(work),requiresReboot=True)
        print('Preparado para el próximo arranque. NO se ha reiniciado el Mac.',flush=True)
        print('Respaldo: '+str(work),flush=True)
    except BaseException:
        if changed and not committed:
            # Restore exactly the previous bundle; the currently running snapshot stays untouched.
            if target.exists():shutil.rmtree(target)
            if previous.exists():os.rename(previous,target)
            run(['/usr/sbin/bless','--mount',MOUNT,'--snapshot',d['APFSSnapshotUUID']])
        raise
    finally:
        if mounted:run(['/sbin/umount',MOUNT])

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);g=p.add_mutually_exclusive_group();g.add_argument('--apply',action='store_true');g.add_argument('--rollback',action='store_true');a=p.parse_args()
    try:perform('apply' if a.apply else 'rollback' if a.rollback else 'check')
    except Exception as e:
        print('No completado: '+str(e),file=sys.stderr)
        detail=getattr(e,'stdout',None)
        if detail:print(detail.decode(errors='replace') if isinstance(detail,bytes) else detail,file=sys.stderr)
        if os.geteuid()==0:receipt('error',error=str(e),detail=detail.decode(errors='replace') if isinstance(detail,bytes) else detail)
        sys.exit(1)
