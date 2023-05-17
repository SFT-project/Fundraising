import fetch from "cross-fetch";

async function getMaxPriorityFeePerGas(networkName: string, params?: any): Promise<any> {
  let url = "https://filecoin.chainup.net/rpc/v1";
  console.log(`network: ${networkName}`)
  if (networkName == "hyperspace") {
    url = process.env.HYPERSPACE_URL as string;
  } 
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "eth_maxPriorityFeePerGas",
      params,
      id: 1,
    }),
  });
  return (await response.json()).result;
}

export { getMaxPriorityFeePerGas }