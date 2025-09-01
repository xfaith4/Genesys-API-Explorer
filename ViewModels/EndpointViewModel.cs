using GenesysCloudOAuthWebView.WinForms;
using System;
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
        public ApiCategory() { }
        private ApiCategory _selectedCategory;
        public ApiCategory SelectedCategory
        {
            get => _selectedCategory;
            set
            {
                if (_selectedCategory != value)
                {
                    _selectedCategory = value;
                    OnPropertyChanged();
                }
            }
        }


        private void OnPropertyChanged()
        {
            throw new NotImplementedException();
        }
    }

    public class ApiEndpoint
    {
        public string Path { get; set; }
        public string Method { get; set; }
        public JsonElement Schema { get; set; }
        public JsonElement OperationElement { get; set; }  // <— add this
        public string DisplayName => $"{Method.ToUpper()} {Path}";
    }
    public class FormField : INotifyPropertyChanged
    {
        public string Name { get; set; }    // e.g., "email (string)"
        private string _value;
        public string Value
        {
            get => _value;
            set { _value = value; OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string propName = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propName));

        protected bool SetProperty<T>(ref T field, T newValue, [CallerMemberName] string propertyName = null)
        {
            if (!Equals(field, newValue))
            {
                field = newValue;
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
                return true;
            }

            return false;
        }

        private object selectedCategory1;

        public object SelectedCategory { get => selectedCategory1; set => SetProperty(ref selectedCategory1, value); }

        private System.Collections.IEnumerable categories;

        public System.Collections.IEnumerable Categories { get => categories; set => SetProperty(ref categories, value); }

        private RelayCommand loginCommand;
        public ICommand LoginCommand => loginCommand ??= new RelayCommand(Login1);

        private void Login1(object commandParameter)
        {
        }

        private RelayCommand submitCommand;
        public ICommand SubmitCommand => submitCommand ??= new RelayCommand(Submit);

        private void Submit(object commandParameter)
        {
        }

        private string currentOperationJson;

        public string CurrentOperationJson { get => currentOperationJson; set => SetProperty(ref currentOperationJson, value); }
    }
    public class EndpointViewModel : EndpointViewModelBase, INotifyPropertyChanged
    {
        // Collections for binding
        public ObservableCollection<ApiCategory> Categories { get; set; } = new();
        public ObservableCollection<FormField> FormFields { get; set; } = new();

        private ApiEndpoint _selectedEndpoint;

        public object CurrentSchema { get; private set; }
        private string _currentOperationJson;

        public string CurrentOperationJson
        {
            get => _currentOperationJson;
            private set
            {
                _currentOperationJson = value;
                OnPropertyChanged();
            }
        }

        public ApiEndpoint SelectedEndpoint
        {
            get => _selectedEndpoint;
            set
            {
                _selectedEndpoint = value;
                OnPropertyChanged();

                if (value != null)
                {
                    // stash the raw operation element
                    var op = value.OperationElement;

                    // pretty-print via GetRawText + reparse
                    var raw = op.GetRawText();
                    try
                    {
                        using var doc = JsonDocument.Parse(raw);
                        CurrentOperationJson = JsonSerializer.Serialize(
                          doc.RootElement,
                          new JsonSerializerOptions { WriteIndented = true }
                        );
                    }
                    catch
                    {
                        CurrentOperationJson = raw;
                    }

                    // your existing schema/form logic…
                    CurrentSchema = ResolveSchema(value.Schema);
                    GenerateFormFields(CurrentSchema);
                }
                else
                {
                    CurrentOperationJson = string.Empty;
                    FormFields.Clear();
                }
            }

        }

        private object ResolveSchema(JsonElement schema)
        {
            throw new NotImplementedException();
        }

        private void GenerateFormFields(object currentSchema)
        {
            throw new NotImplementedException();
        }

        private void GenerateFormFields(JsonElement schema)
        {
            FormFields.Clear();

            // nothing to edit if no properties
            if (schema.ValueKind != JsonValueKind.Object
             || !schema.TryGetProperty("properties", out var props))
            {
                return;
            }

            foreach (var prop in props.EnumerateObject())
            {
                string name = prop.Name;

                // get the property schema (type, example/default, etc.)
                JsonElement propSchema = prop.Value;
                string type = "object";
                if (propSchema.TryGetProperty("type", out var typeElem))
                    type = typeElem.GetString() ?? type;

                // pick up an example or default if provided
                string example = "";
                if (propSchema.TryGetProperty("example", out var ex))
                    example = ex.ToString();
                else if (propSchema.TryGetProperty("default", out var def))
                    example = def.ToString();

                // add it to the VM’s FormFields
                FormFields.Add(new FormField
                {
                    Name = $"{name} ({type})",
                    Value = example
                });
            }
        }

        /// <summary>
        /// Turn a JSON‐schema‐object into a collection of name+value FormField instances.
        /// </summary>

        private string _responseText;
        public string ResponseText
        {
            get => _responseText;
            set { _responseText = value; OnPropertyChanged(); }
        }

        // OAuth token and region info
        private string _apiToken;
        private string _regionHost = "mypurecloud.com"; // default to US East
        // Commands for UI binding
        public ICommand SubmitCommand { get; }
        public ICommand LoginCommand { get; }
        private OAuthWebViewForm _authForm;
        public EndpointViewModel(long v)
        {
            SubmitCommand = new RelayCommand(_ => SubmitApiCall());
            LoginCommand = new RelayCommand(_ => Login(GetAuthForm()));
            // Attempt to read region from installer-generated config (if exists)
            LoadRegionConfig();
            this.v = v;
        }

        private OAuthWebViewForm GetAuthForm()
        {
            if (_authForm != null)
            {
                return _authForm;
                // if you need to tweak owner or styling, do it here
            }
            _authForm = new OAuthWebViewForm();
            return _authForm;
        }

        /// <summary>
        /// Loads and parses the embedded Swagger JSON, populating Categories and Endpoints.
        /// </summary>
        /// // Keep the Swagger document around for as long as the VM lives:
        private JsonDocument _swaggerDoc;
        public void LoadSwagger()
        {
            var asm = Assembly.GetExecutingAssembly();
            string resourceName = asm.GetManifestResourceNames()
                                      .First(n => n.EndsWith("GenesysCloudAPIEndpoints.json"));

            using Stream jsonStream = asm.GetManifestResourceStream(resourceName);
            // ← no "using" on the JsonDocument itself
            _swaggerDoc = JsonDocument.Parse(jsonStream);

            JsonElement paths = _swaggerDoc.RootElement.GetProperty("paths");

            // Group endpoints by first path segment (category)
            var tagMap = new System.Collections.Generic.Dictionary<string, ApiCategory>();
            foreach (JsonProperty pathProp in paths.EnumerateObject())
            {
                string path = pathProp.Name;                   // e.g., "/api/v2/conversations/{id}"
                JsonElement methods = pathProp.Value;          // the object containing methods (get, post, etc.)
                // Each method entry has an array of "tags" (categories)
                foreach (JsonProperty methodProp in methods.EnumerateObject())
                {
                    string methodName = methodProp.Name;       // e.g., "get", "post"
                    JsonElement operation = methodProp.Value;
                    string tag = operation.GetProperty("tags")[0].GetString(); // primary tag
                    if (!tagMap.ContainsKey(tag))
                        tagMap[tag] = new ApiCategory { Name = tag };
                    // Extract request schema (if any body parameter)
                    JsonElement schema = default;
                    if (operation.TryGetProperty("parameters", out JsonElement paramsArray))
                    {
                        foreach (JsonElement param in paramsArray.EnumerateArray())
                        {
                            if (param.GetProperty("in").GetString() == "body")
                            {
                                // If a body parameter is defined, capture its schema
                                if (param.TryGetProperty("schema", out JsonElement sch))
                                {
                                    schema = sch;
                                }
                            }
                        }
                    }
                    // Create an ApiEndpoint entry
                    var apiEndpoint = new ApiEndpoint
                    {
                        Path = path,
                        Method = methodName,
                        Schema = schema,
                        OperationElement = operation   // <— stash it here
                    };
                    tagMap[tag].Endpoints.Add(apiEndpoint);
                }
            }
            Categories.Clear();
            foreach (var cat in tagMap.Values.OrderBy(c => c.Name))
            {
                // Sort endpoints by path for each category
                cat.Endpoints = new ObservableCollection<ApiEndpoint>(
                                    cat.Endpoints.OrderBy(static ep => ep.Path));
                Categories.Add(cat);
            }
        }

        /// <summary>
        /// Opens the Genesys Cloud OAuth login dialog and retrieves an access token.
        /// </summary>
        private void Login(OAuthWebViewForm authForm)
        {
            // OAuth client credentials (fill in your OAuth Client ID; secret not needed for implicit)
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
                DialogResult result = authForm.ShowDialog();  // opens a modal web login window
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

        /// <summary>
        /// Submits the selected API call with user inputs, and sets ResponseText with the result or error.
        /// </summary>
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

            // Prepare HTTP request (using HttpClient)
            string baseUrl = $"https://api.{_regionHost}/api/v2"; // e.g., https://api.mypurecloud.ie/api/v2
            string url = baseUrl + SelectedEndpoint.Path;
            string method = SelectedEndpoint.Method.ToUpper();
            HttpClient client = new();
            client.DefaultRequestHeaders.Add("Authorization", $"Bearer {_apiToken}");

            // If we had query or path parameters, we'd replace/add them here.
            // (For simplicity, assuming all inputs are body fields as handled by FormFields.)
            string jsonBody = null;
            if (FormFields.Count > 0)
            {
                var payload = new System.Collections.Generic.Dictionary<string, object>();
                foreach (var field in FormFields)
                {
                    payload[field.Name.Split(' ')[0]] = field.Value;
                }
                jsonBody = JsonSerializer.Serialize(payload);
            }

            try
            {
                HttpResponseMessage response;
                if (method == "GET")
                {
                    response = await client.GetAsync(url);
                }
                else if (method == "POST")
                {
                    response = await client.PostAsync(url,
                                new StringContent(jsonBody ?? "", System.Text.Encoding.UTF8, "application/json"));
                }
                else if (method == "PUT")
                {
                    response = await client.PutAsync(url,
                                new StringContent(jsonBody ?? "", System.Text.Encoding.UTF8, "application/json"));
                }
                else if (method == "PATCH")
                {
                    var request = new HttpRequestMessage(new HttpMethod("PATCH"), url)
                    {
                        Content = new StringContent(jsonBody ?? "", System.Text.Encoding.UTF8, "application/json")
                    };
                    response = await client.SendAsync(request);
                }
                else if (method == "DELETE")
                {
                    response = await client.DeleteAsync(url);
                }
                else
                {
                    ResponseText = $"Method {method} not implemented in client.";
                    return;
                }

                string responseText = await response.Content.ReadAsStringAsync();
                if (response.IsSuccessStatusCode)
                {
                    // Pretty-print JSON if possible
                    try
                    {
                        using var doc = JsonDocument.Parse(responseText);
                        responseText = JsonSerializer.Serialize(doc.RootElement, new JsonSerializerOptions { WriteIndented = true });
                    }
                    catch { /* not JSON or parse failed, keep raw */ }
                    ResponseText = responseText;
                }
                else
                {
                    ResponseText = $"Error {response.StatusCode}:\n{responseText}";
                }
            }
            catch (Exception ex)
            {
                ResponseText = $"Request failed: {ex.Message}";
            }
        }

        /// <summary>
        /// Reads the region config file (if present) to set the _regionHost.
        /// This config is written by the installer custom page.
        /// </summary>
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
                        {
                            _regionHost = line["Region=".Length..].Trim();
                        }
                    }
                }
            }
            catch
            {
                // If any error in reading config, default remains in place.
            }
        }

        // INotifyPropertyChanged implementation:
        public event PropertyChangedEventHandler PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string propName = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propName));

        protected bool SetProperty<T>(ref T field, T newValue, [CallerMemberName] string propertyName = null)
        {
            if (!Equals(field, newValue))
            {
                field = newValue;
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
                return true;
            }

            return false;
        }

        private object selectedCategory;
        private readonly long v;

        public object SelectedCategory { get => selectedCategory; set => SetProperty(ref selectedCategory, value); }
    }

    internal record struct NewStruct(OAuthWebViewForm Item1, OAuthWebViewForm Item2)
    {
        public static implicit operator (OAuthWebViewForm, OAuthWebViewForm)(NewStruct value)
        {
            return (value.Item1, value.Item2);
        }

        public static implicit operator NewStruct((OAuthWebViewForm, OAuthWebViewForm) value)
        {
            return new NewStruct(value.Item1, value.Item2);
        }
    }
}