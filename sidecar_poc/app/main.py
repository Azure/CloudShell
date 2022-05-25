from typing import Union
import os,shutil
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/upgrade/az_cli/")
def read_item():
    with open('/tmp/upgrade_az_cli.sh', 'w') as f:
        f.write('apt-get install --only-upgrade -y azure-cli')
        os.chmod("/tmp/upgrade_az_cli.sh",0o755)
        shutil.move("/tmp/upgrade_az_cli.sh","/tmp/pkgs/upgrade_az_cli.sh")
