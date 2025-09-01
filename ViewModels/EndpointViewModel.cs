using GenesysCloudOAuthWebView.WinForms;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Windows.Forms;
using System.Windows.Input;

namespace GenesysApiExplorer.ViewModels
{
    public class ApiCategory
    {
        public string Name { get; set; }
        public ObservableCollection<ApiEndpoint> Endpoints { get; set; } = new();
    }

    public class ApiEndpoint : INotifyPropertyChanged
    {
        public string Path { get; set; }
        public string Method { get; set; }
        public JsonElement Schema { get; set; }
        public JsonElement OperationElement { get; set; }

        public string DisplayName => $"{Method.ToUpper()} {Path}";

        private bool _isFavorite;
        public bool IsFavorite
        {
            get => _isFavorite;
            set { _isFavorite = value; OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string name = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    public class FormField : INotifyPropertyChanged
    {
        public string Name { get; set; }
        private string _value;
        public string Value
        {
            get => _value;
            set { _value = value; OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string name = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    public class EndpointViewModel : EndpointViewModelBase, INotifyPropertyChanged
    {
        public ObservableCollection<ApiCategory> Categories { get; } = new();
        public ObservableCollection<FormField> FormFields { get; } = new();

        private ApiEndpoint _selectedEndpoint;
        public ApiEndpoint SelectedEndpoint
        {
            get => _selectedEndpoint;
            set
            {
                if (SetProperty(ref _selectedEndpoint, value))
                {
                    if (value != null)
                    {
                        CurrentOperationJson = PrettyJson(value.OperationElement);
                        GenerateFormFields(value.Schema);
                    }
                    else
                    {
                        CurrentOperationJson = string.Empty;
                        FormFields.Clear();
                    }
                    CommandManager.InvalidateRequerySuggested();
                }
            }
        }

        private string _currentOperationJson;
        public string CurrentOperationJson
        {
            get => _currentOperationJson;
            private set => SetProperty(ref _currentOperationJson, value);
        }

        private string _responseText;
        public string ResponseText
        {
            get => _responseText;
            set => SetProperty(ref _responseText, value);
        }

        private readonly string _favoritesPath = Path.Combine(AppContext.BaseDirectory, "favorites.json");
        private readonly HashSet<string> _favorites = new();

        private readonly string _logPath = Path.Combine(AppContext.BaseDirectory, "api.log");

        private string _apiToken;
        private string _regionHost = "mypurecloud.com";
        private OAuthWebViewForm _authForm;

        public ICommand SubmitCommand { get; }
        public ICommand LoginCommand { get; }
        public ICommand ToggleFavoriteCommand { get; }

        public EndpointViewModel()
        {
            SubmitCommand = new RelayCommand(_ => SubmitApiCall());
            LoginCommand = new RelayCommand(_ => Login(GetAuthForm()));
            ToggleFavoriteCommand = new RelayCommand(_ => ToggleFavorite(), _ => SelectedEndpoint != null);

            LoadFavorites();
            LoadRegionConfig();
        }

        private OAuthWebViewForm GetAuthForm()
        {
            _authForm ??= new OAuthWebViewForm();
            return _authForm;
        }

        private void LoadFavorites()
        {
            try
            {
                if (File.Exists(_favoritesPath))
                {
                    var favs = JsonSerializer.Deserialize<List<string>>(File.ReadAllText(_favoritesPath));
                    if (favs != null)
                        _favorites.UnionWith(favs);
                }
            }
            catch { }
        }

        private void SaveFavorites()
        {
            try
            {
                File.WriteAllText(_favoritesPath, JsonSerializer.Serialize(_favorites));
            }
            catch { }
        }

        private string KeyFor(ApiEndpoint ep) => $"{ep.Method}:{ep.Path}";

        private void ToggleFavorite()
        {
            if (SelectedEndpoint == null) return;
            string key = KeyFor(SelectedEndpoint);
            if (_favorites.Contains(key))
            {
                _favorites.Remove(key);
                SelectedEndpoint.IsFavorite = false;
            }
            else
            {
                _favorites.Add(key);
                SelectedEndpoint.IsFavorite = true;
            }
            SaveFavorites();
        }

        public void LoadSwagger()
        {
            var asm = Assembly.GetExecutingAssembly();
            string resourceName = asm.GetManifestResourceNames().First(n => n.EndsWith("GenesysCloudAPIEndpoints.json"));

            using Stream jsonStream = asm.GetManifestResourceStream(resourceName);
            using var doc = JsonDocument.Parse(jsonStream);
            JsonElement paths = doc.RootElement.GetProperty("paths");

            var tagMap = new Dictionary<string, ApiCategory>();

            foreach (JsonProperty pathProp in paths.EnumerateObject())
            {
                string path = pathProp.Name;
                JsonElement methods = pathProp.Value;
                foreach (JsonProperty methodProp in methods.EnumerateObject())
                {
                    string methodName = methodProp.Name;
                    JsonElement operation = methodProp.Value;
                    string tag = operation.GetProperty("tags")[0].GetString();
                    if (!tagMap.ContainsKey(tag))
                        tagMap[tag] = new ApiCategory { Name = tag };

                    JsonElement schema = default;
                    if (operation.TryGetProperty("parameters", out JsonElement paramsArray))
                    {
                        foreach (JsonElement param in paramsArray.EnumerateArray())
                        {
                            if (param.GetProperty("in").GetString() == "body" && param.TryGetProperty("schema", out JsonElement sch))
                            {
                                schema = sch;
                            }
                        }
                    }
                    var endpoint = new ApiEndpoint
                    {
                        Path = path,
                        Method = methodName,
                        Schema = schema,
                        OperationElement = operation,
                        IsFavorite = _favorites.Contains($"{methodName}:{path}")
                    };
                    tagMap[tag].Endpoints.Add(endpoint);
                }
            }

            Categories.Clear();
            foreach (var cat in tagMap.Values.OrderBy(c => c.Name))
            {
                cat.Endpoints = new ObservableCollection<ApiEndpoint>(cat.Endpoints.OrderBy(ep => ep.Path));
                Categories.Add(cat);
            }
        }

        private string PrettyJson(JsonElement element)
        {
            try
            {
                using var doc = JsonDocument.Parse(element.GetRawText());
                return JsonSerializer.Serialize(doc.RootElement, new JsonSerializerOptions { WriteIndented = true });
            }
            catch
            {
                return element.GetRawText();
            }
        }

        private void GenerateFormFields(JsonElement schema)
        {
            FormFields.Clear();

            if (schema.ValueKind != JsonValueKind.Object || !schema.TryGetProperty("properties", out var props))
                return;

            foreach (var prop in props.EnumerateObject())
            {
                string name = prop.Name;
                JsonElement propSchema = prop.Value;
                string type = propSchema.TryGetProperty("type", out var typeElem) ? typeElem.GetString() ?? "object" : "object";
                string example = "";
                if (propSchema.TryGetProperty("example", out var ex))
                    example = ex.ToString();
                else if (propSchema.TryGetProperty("default", out var def))
                    example = def.ToString();

                FormFields.Add(new FormField
                {
                    Name = $"{name} ({type})",
                    Value = example
                });
            }
        }

        private void Login(OAuthWebViewForm authForm)
        {
            string clientId = "YOUR-CLIENT-ID-HERE";
            if (string.IsNullOrEmpty(clientId))
            {
                ResponseText = "Error: OAuth ClientId not configured.";
                return;
            }

            authForm.oAuthWebView.Config.ClientId = clientId;
            authForm.oAuthWebView.Config.RedirectUri = "http://localhost:8080";
            authForm.oAuthWebView.Config.RedirectUriIsFake = true;
            authForm.oAuthWebView.Config.Environment = _regionHost;
            try
            {
                DialogResult result = authForm.ShowDialog();
                if (result == DialogResult.OK)
                {
                    _apiToken = authForm.oAuthWebView.AccessToken;
                    ResponseText = "Login successful. Token acquired.";
                }
                else
                {
                    ResponseText = "Login canceled or failed.";
                }
            }
            catch (Exception ex)
            {
                ResponseText = $"Login error: {ex.Message}";
            }
        }

        private async void SubmitApiCall()
        {
            if (SelectedEndpoint == null)
            {
                ResponseText = "No endpoint selected.";
                return;
            }
            if (string.IsNullOrEmpty(_apiToken))
            {
                ResponseText = "Error: Not authenticated. Please login first.";
                return;
            }

            string baseUrl = $"https://api.{_regionHost}/api/v2";
            string url = baseUrl + SelectedEndpoint.Path;
            string method = SelectedEndpoint.Method.ToUpper();
            HttpClient client = new();
            client.DefaultRequestHeaders.Add("Authorization", $"Bearer {_apiToken}");

            string jsonBody = null;
            if (FormFields.Count > 0)
            {
                var payload = new Dictionary<string, object>();
                foreach (var field in FormFields)
                {
                    payload[field.Name.Split(' ')[0]] = field.Value;
                }
                jsonBody = JsonSerializer.Serialize(payload);
            }

            Log($"Request: {method} {url}\n{jsonBody}");

            try
            {
                HttpResponseMessage response;
                if (method == "GET")
                    response = await client.GetAsync(url);
                else if (method == "POST")
                    response = await client.PostAsync(url, new StringContent(jsonBody ?? "", System.Text.Encoding.UTF8, "application/json"));
                else if (method == "PUT")
                    response = await client.PutAsync(url, new StringContent(jsonBody ?? "", System.Text.Encoding.UTF8, "application/json"));
                else if (method == "PATCH")
                    response = await client.SendAsync(new HttpRequestMessage(new HttpMethod("PATCH"), url) { Content = new StringContent(jsonBody ?? "", System.Text.Encoding.UTF8, "application/json") });
                else if (method == "DELETE")
                    response = await client.DeleteAsync(url);
                else
                {
                    ResponseText = $"Method {method} not implemented in client.";
                    return;
                }

                string responseText = await response.Content.ReadAsStringAsync();
                Log($"Response: {(int)response.StatusCode} {response.StatusCode}\n{responseText}");

                if (response.IsSuccessStatusCode)
                {
                    try
                    {
                        using var doc = JsonDocument.Parse(responseText);
                        responseText = JsonSerializer.Serialize(doc.RootElement, new JsonSerializerOptions { WriteIndented = true });
                    }
                    catch { }
                    ResponseText = responseText;
                }
                else
                {
                    ResponseText = $"Error {response.StatusCode}:\n{responseText}";
                }
            }
            catch (Exception ex)
            {
                Log($"Error: {ex}");
                ResponseText = $"Request failed: {ex.Message}";
            }
        }

        private void Log(string text)
        {
            try
            {
                File.AppendAllText(_logPath, $"[{DateTime.Now:O}] {text}\n\n");
            }
            catch { }
        }

        private void LoadRegionConfig()
        {
            try
            {
                string cfgPath = Path.Combine(AppContext.BaseDirectory, "userconfig.ini");
                if (File.Exists(cfgPath))
                {
                    foreach (var line in File.ReadAllLines(cfgPath))
                    {
                        if (line.StartsWith("Region="))
                            _regionHost = line["Region=".Length..].Trim();
                    }
                }
            }
            catch { }
        }

        public event PropertyChangedEventHandler PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string name = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

        protected bool SetProperty<T>(ref T field, T value, [CallerMemberName] string name = null)
        {
            if (!EqualityComparer<T>.Default.Equals(field, value))
            {
                field = value;
                OnPropertyChanged(name);
                return true;
            }
            return false;
        }
    }
}
