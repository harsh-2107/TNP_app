#Email bhej

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Any

from app.core.config import get_settings
from app.core.logging import get_logger

logger = get_logger(__name__)


class EmailService:
  

    @classmethod
    async def send_email(cls, to_email: str, subject: str, body: str) -> None:
       
        # Falls backif SMTP host keys are missing.
       
        if not to_email:
            logger.warning("Attempted to send email but recipient address is empty.")
            return

        settings = get_settings()

        smtp_host = getattr(settings, "SMTP_HOST", None)
        smtp_port = getattr(settings, "SMTP_PORT", 587)
        smtp_user = getattr(settings, "SMTP_USER", None)
        smtp_pass = getattr(settings, "SMTP_PASS", None)
        from_email = getattr(settings, "SMTP_FROM_EMAIL", "tnp@iiitn.ac.in")

        if smtp_host and smtp_user and smtp_pass:
            try:
                msg = MIMEMultipart()
                msg["From"] = from_email
                msg["To"] = to_email
                msg["Subject"] = subject
                msg.attach(MIMEText(body, "plain"))

                import asyncio
                loop = asyncio.get_event_loop()

                def _send_smtp():
                    with smtplib.SMTP(smtp_host, smtp_port) as server:
                        server.starttls()
                        server.login(smtp_user, smtp_pass)
                        server.sendmail(from_email, to_email, msg.as_string())

                await loop.run_in_executor(None, _send_smtp)
                logger.info("Successfully sent SMTP email to=%s subject=%s", to_email, subject)
            except Exception as exc:
                logger.error("Failed to send SMTP email to %s: %s. Falling back to log print.", to_email, exc)
                cls._log_mock_email(to_email, subject, body)
        else:
            cls._log_mock_email(to_email, subject, body)

    @classmethod
    def _log_mock_email(cls, to_email: str, subject: str, body: str) -> None:
        """Helper to print formatted mock emails to logging stdout."""
        logger.info(
            "\n"
            "======================================================================\n"
            "[MOCK EMAIL OUTBOX]\n"
            "----------------------------------------------------------------------\n"
            "To:      %s\n"
            "Subject: %s\n"
            "----------------------------------------------------------------------\n"
            "%s\n"
            "======================================================================",
            to_email,
            subject,
            body,
        )
