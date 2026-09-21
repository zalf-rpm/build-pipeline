import asyncio
import time
from openai import AsyncOpenAI

# CONFIGURATION
API_URL = "http://localhost:8000/v1"  # Passe den Port an deine Instanz an
MODEL_NAME = "Qwen/Qwen3.8-27B"       # Exakt der Name aus deinem Startbefehl
CONCURRENT_REQUESTS = 4               # Wie viele Nutzer gleichzeitig anfragen
PROMPT = "Schreibe einen ausführlichen, technischen Essay über die Zukunft von Quantencomputing und KI."

async def measure_single_request(client, request_id):
    start_time = time.time()
    ttft = None
    token_count = 0
    
    try:
        response = await client.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": PROMPT}],
            max_tokens=256, # Begrenzung, damit der Test schnell durchläuft
            stream=True     # Stream aktivieren, um den ersten Token zu messen
        )
        
        async for chunk in response:
            if chunk.choices and chunk.choices[0].delta.content:
                if ttft is None:
                    # Erste Antwort erhalten -> TTFT berechnen
                    ttft = time.time() - start_time
                token_count += 1
                
        total_time = time.time() - start_time
        # Generierungszeit ab dem ersten Token
        generation_time = total_time - ttft if ttft else total_time
        tps = token_count / generation_time if generation_time > 0 else 0

        # ttft kann None bleiben, falls kein Content-Chunk empfangen wurde (z.B. 0 Tokens)
        ttft_str = f"{ttft:.3f}s" if ttft is not None else "n/a"
        print(f" Request {request_id}: Fertig. TTFT: {ttft_str} | TPS: {tps:.1f} | Gesamtzeit: {total_time:.2f}s ({token_count} Tokens)")
        return ttft, tps
        
    except Exception as e:
        print(f"❌ Request {request_id} fehlgeschlagen: {e}")
        return None, None

async def main():
    client = AsyncOpenAI(base_url=API_URL, api_key="token-not-needed")
    print(f" Starte Benchmark gegen vLLM auf {API_URL}...")
    print(f" Modell: {MODEL_NAME}")
    print(f" Simuliere {CONCURRENT_REQUESTS} gleichzeitige Nutzer...\n")
    
    start_total_benchmark = time.time()
    
    # Alle Anfragen gleichzeitig abschicken
    tasks = [measure_single_request(client, i+1) for i in range(CONCURRENT_REQUESTS)]
    results = await asyncio.gather(*tasks)
    
    end_total_benchmark = time.time()
    
    # Ergebnisse filtern und auswerten
    valid_results = [r for r in results if r[0] is not None]
    if not valid_results:
        print("Keine erfolgreichen Requests gemessen.")
        return
        
    avg_ttft = sum(r[0] for r in valid_results) / len(valid_results)
    avg_tps = sum(r[1] for r in valid_results) / len(valid_results)
    total_duration = end_total_benchmark - start_total_benchmark
    
    print("\n" + "="*50)
    print("📊 BENCHMARK ERGEBNISSE (H100 GPU)")
    print("="*50)
    print(f"Durchschnittliche Antwortzeit (TTFT): {avg_ttft:.3f} Sekunden")
    print(f"Durchschnittliche Geschwindigkeit:     {avg_tps:.1f} Tokens/Sekunde pro Nutzer")
    print(f"Knoten-Gesamtdurchsatz (kumuliert):    {avg_tps * len(valid_results):.1f} Tokens/Sekunde")
    print(f"Gesamtdauer des Benchmarks:           {total_duration:.2f} Sekunden")
    print("="*50)

if __name__ == "__main__":
    asyncio.run(main())