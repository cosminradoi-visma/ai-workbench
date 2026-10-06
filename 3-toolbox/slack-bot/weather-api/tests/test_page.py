def test_page_is_html(client):
    r = client.get("/")
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/html")


def test_page_has_forecast_list(client):
    assert 'id="days"' in client.get("/").text
