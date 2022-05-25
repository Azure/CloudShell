FROM python:3.9 
WORKDIR /code
RUN mkdir /tmp/pkgs/ 
COPY sidecar_poc/requirements.txt /code/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt
COPY sidecar_poc/app /code/app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "80"]
