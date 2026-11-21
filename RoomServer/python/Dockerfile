FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY wheattalk ./wheattalk
COPY server.py config.json ./

RUN useradd --system --create-home --uid 10001 chatroom

USER chatroom

EXPOSE 6510/tcp
EXPOSE 6511/udp

CMD ["python", "server.py"]
