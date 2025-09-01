using GenesysApiExplorer.ViewModels;
using System.Windows;

namespace GenesysApiExplorer
{
    public partial class MainWindow : Window
    {
        private readonly EndpointViewModel ViewModel;

        public MainWindow()
        {
            InitializeComponent();
            ViewModel = new EndpointViewModel();
            DataContext = ViewModel;
            ViewModel.LoadSwagger();
        }

        private void TreeView_SelectedItemChanged(object sender, RoutedPropertyChangedEventArgs<object> e)
        {
            // When a user selects an endpoint (method node) in the TreeView, set it in the ViewModel
            if (e.NewValue is ApiEndpoint endpoint)
            {
                ViewModel.SelectedEndpoint = endpoint;
            }
        }
    }
}
