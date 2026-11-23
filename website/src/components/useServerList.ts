import { useCallback, useEffect, useState } from 'react';
import type { ApiResponse } from '../services/api.service';
import { getApiErrorMessage } from '../utils/error-message';

// Ignore responses from a previous page or a panel that has been closed.
export function useServerList<T>(load: () => Promise<ApiResponse<T>>) {
  const [revision, setRevision] = useState(0);
  const [result, setResult] = useState<{
    query: typeof load; revision: number; data?: T; error?: string;
  }>();
  const refresh = useCallback(() => setRevision(value => value + 1), []);
  useEffect(() => {
    let current = true;
    void load().then(result => {
      if (!result.success || result.data == null) throw new Error(result.message || '加载失败');
      if (current) setResult({ query: load, revision, data: result.data });
    }).catch(error => {
      if (current) setResult({ query: load, revision, error: getApiErrorMessage(error, '加载失败，请重试') });
    });
    return () => { current = false; };
  }, [load, revision]);
  const matching = result?.query === load ? result : undefined;
  const loading = matching?.revision !== revision;
  return { data: matching?.data, error: loading ? undefined : matching?.error, loading, refresh };
}
