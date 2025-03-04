//provider.js
"use client";
import { Provider } from "react-redux";
import { store } from "."

export function Providers({ children }) {
  return <Provider store={store} >
    {/* <PersistGate loading={null} persistor={persistor}> */}
      {children}
    {/* </PersistGate> */}
  </Provider>;
}