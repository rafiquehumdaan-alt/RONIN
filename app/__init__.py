from flask import Flask
from .routes import api


def create_app(config=None):
    app = Flask(__name__)
    if config:
        app.config.update(config)
    app.register_blueprint(api)

    @app.after_request
    def secure(r):
        r.headers.update(
            {
                "X-Content-Type-Options": "nosniff",
                "X-Frame-Options": "DENY",
                "Referrer-Policy": "no-referrer",
                "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
                "Content-Security-Policy": "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'",
            }
        )
        return r

    return app
