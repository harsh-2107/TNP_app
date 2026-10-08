import httpx
import asyncio

async def test():
    url = "https://api.emailjs.com/api/v1.0/email/send"
    payload = {
        "service_id": "service_bingg9y",
        "template_id": "template_nzz7tub",
        "user_id": "tgXQnm6Ny5BM76wzS",
        "template_params": {
            "to_email": "test@example.com",
            "subject": "Test Email",
            "message": "This is a test message"
        },
        "accessToken": "FuH-6Y6jiOsn9a5nYsaUJ"
    }
    async with httpx.AsyncClient() as client:
        r = await client.post(url, json=payload)
        print("Status:", r.status_code)
        print("Response:", r.text)

asyncio.run(test())
