import ReactDOM from 'react-dom/client';
import { ConfigProvider } from 'antd';
import { BrowserRouter } from 'react-router-dom';
import 'antd/dist/reset.css';
import App from './App';
import { adminTheme } from './app/theme';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <ConfigProvider theme={adminTheme}>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </ConfigProvider>,
);
