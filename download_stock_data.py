import os
import threading
import time
from concurrent.futures import ThreadPoolExecutor

import pandas as pd
import requests


API_KEY = ""

counter = 0
counter_lock = threading.Lock()
total_tickers = 0


def get_fundamentals(ticker, period, data_type):
    url = (
        f"https://api.roic.ai/v2/fundamental/{data_type}/{ticker}"
        f"?apikey={API_KEY}&period={period}&limit=250"
    )
    response = requests.get(url)

    if response.status_code == 200:
        return response.json()
    if response.status_code == 429:
        time.sleep(30)
        return None
    return None


def get_prices(ticker):
    url = (
        f"https://api.roic.ai/v2/stock-prices/{ticker}"
        f"?apikey={API_KEY}&limit=100000"
    )
    response = requests.get(url)

    if response.status_code == 200:
        return response.json()
    if response.status_code == 429:
        time.sleep(30)
        return None
    return None


def get_company_data(ticker, data_type):
    url = f"https://api.roic.ai/v2/company/{data_type}/{ticker}?apikey={API_KEY}"

    if data_type == "news":
        url += "&limit=200"

    response = requests.get(url)
    if response.status_code == 200:
        return response.json()
    if response.status_code == 429:
        time.sleep(30)
        return None
    return None


def get_earnings_calls(ticker, year, quarter):
    url = (
        f"https://api.roic.ai/v2/company/earnings-calls/transcript/{ticker}"
        f"?apikey={API_KEY}&year={year}&quarter={quarter}"
    )

    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            if isinstance(data, dict) and "error" in data:
                return {"year": year, "quarter": f"Q{quarter}", "content": "No data found in API"}

            if isinstance(data, dict):
                data["year"] = year
                data["quarter"] = f"Q{quarter}"
            return data
        return {"year": year, "quarter": f"Q{quarter}", "content": f"No data (Error {response.status_code})"}
    except Exception as exc:
        return {"year": year, "quarter": f"Q{quarter}", "content": f"Connection Error: {exc}"}


def save_data(data, ticker, period, data_type):
    if not data:
        return

    directory_name = f"data/{ticker}/{data_type.replace('-', '_')}"
    os.makedirs(directory_name, exist_ok=True)

    df = pd.DataFrame(data)
    filename = f"{directory_name}/{ticker}_{period}_{data_type.replace('/', '_').replace('-', '_')}.xlsx"
    df.to_excel(filename, index=False, engine="openpyxl")


def save_price_data(data, ticker):
    if not data:
        return

    directory_name = f"data/{ticker}/price"
    os.makedirs(directory_name, exist_ok=True)

    df = pd.DataFrame(data)
    filename = f"{directory_name}/{ticker}_price.xlsx"
    df.to_excel(filename, index=False, engine="openpyxl")


def save_company_data(data, ticker, data_type):
    if not data:
        return

    directory_name = f"data/{ticker}/company_data"
    os.makedirs(directory_name, exist_ok=True)

    df = pd.DataFrame(data)
    filename = f"{directory_name}/{ticker}_{data_type}.xlsx"
    df.to_excel(filename, index=False, engine="openpyxl")


def load_and_save_all_earnings_calls(ticker):
    all_results = []
    directory_name = f"data/{ticker}/company_data"
    os.makedirs(directory_name, exist_ok=True)

    for year in range(2025, 1949, -1):
        for quarter in range(4, 0, -1):
            data = get_earnings_calls(ticker, year, quarter)
            if data:
                all_results.append(data)

    df = pd.DataFrame(all_results)
    filename = f"{directory_name}/{ticker}_earnings_calls.csv"
    df.to_csv(filename, index=False, encoding="utf-8-sig", sep=";")


def save_all_data_from_tickers_list(ticker_list):
    periods = ["annual", "quarterly", "ttm"]
    fundamentals_types = [
        "income-statement",
        "balance-sheet",
        "cash-flow",
        "ratios/profitability",
        "ratios/credit",
        "ratios/liquidity",
        "ratios/working-capital",
        "ratios/yield-analysis",
        "enterprise-value",
        "multiples",
        "per-share",
    ]

    local_counter = 0
    total = len(ticker_list)

    for ticker in ticker_list:
        save_price_data(get_prices(ticker), ticker)
        save_company_data(get_company_data(ticker, "profile"), ticker, "profile")

        for data_type in fundamentals_types:
            for period in periods:
                data = get_fundamentals(ticker, period, data_type)
                save_data(data, ticker, period, data_type)

        local_counter += 1
        percent = (local_counter / total) * 100 if total else 0
        print(f"[{local_counter}/{total}] {percent:.2f}% - Downloaded: {ticker}")


def get_filtered_tickers(exchange):
    try:
        url = f"https://api.roic.ai/v2/tickers/search/exchange/{exchange}?apikey={API_KEY}"
        response = requests.get(url)
        response.raise_for_status()

        data = response.json()
        valid_exchange_names = [
            "NASDAQ Global Select",
            "NASDAQ Global Market",
            "New York Stock Exchange",
        ]

        return [
            item["symbol"]
            for item in data
            if item.get("exchange_name") in valid_exchange_names and item.get("type") == "stock"
        ]
    except requests.exceptions.RequestException as exc:
        print(f"API error: {exc}")
        return []


def process_single_ticker(ticker):
    global counter

    periods = ["annual", "quarterly", "ttm"]
    fundamentals_types = [
        "income-statement",
        "balance-sheet",
        "cash-flow",
        "ratios/profitability",
        "ratios/credit",
        "ratios/liquidity",
        "ratios/working-capital",
        "ratios/yield-analysis",
        "enterprise-value",
        "multiples",
        "per-share",
    ]

    directory_path = f"data/{ticker}"

    if os.path.exists(directory_path) and len(os.listdir(directory_path)) > 0:
        with counter_lock:
            counter += 1
            percent = (counter / total_tickers) * 100 if total_tickers else 0
            print(f"[{counter}/{total_tickers}] {percent:.2f}% - Skipped: {ticker}")
        return

    try:
        save_price_data(get_prices(ticker), ticker)
        save_company_data(get_company_data(ticker, "profile"), ticker, "profile")

        for data_type in fundamentals_types:
            for period in periods:
                data = get_fundamentals(ticker, period, data_type)
                if data:
                    save_data(data, ticker, period, data_type)

        with counter_lock:
            counter += 1
            percent = (counter / total_tickers) * 100 if total_tickers else 0
            print(f"[{counter}/{total_tickers}] {percent:.2f}% - Downloaded: {ticker}")
    except Exception as exc:
        with counter_lock:
            counter += 1
            print(f"[{counter}/{total_tickers}] Download error: {ticker} - {exc}")


def run_all(tickers_list):
    global total_tickers, counter
    total_tickers = len(tickers_list)
    counter = 0

    with ThreadPoolExecutor(max_workers=30) as executor:
        executor.map(process_single_ticker, tickers_list)


if __name__ == "__main__":
    tickers = get_filtered_tickers("NYSE")
    run_all(tickers)
