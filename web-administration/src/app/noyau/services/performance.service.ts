import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable, fromEvent, timer } from 'rxjs';
import { debounceTime, distinctUntilChanged, map, startWith } from 'rxjs/operators';

export interface PerformanceMetrics {
  memoryUsage: number;
  cacheSize: number;
  apiResponseTime: number;
  renderTime: number;
  errorRate: number;
  activeConnections: number;
}

export interface CacheItem<T> {
  data: T;
  timestamp: number;
  ttl: number;
  hits: number;
}

@Injectable({
  providedIn: 'root'
})
export class PerformanceService {
  private readonly cache = new Map<string, CacheItem<any>>();
  private readonly _performanceMetrics$ = new BehaviorSubject<PerformanceMetrics>({
    memoryUsage: 0,
    cacheSize: 0,
    apiResponseTime: 0,
    renderTime: 0,
    errorRate: 0,
    activeConnections: 0
  });

  private readonly defaultTTL = 5 * 60 * 1000; // 5 minutes
  private readonly maxCacheSize = 100; // Maximum 100 items in cache

  constructor() {
    this.initializePerformanceMonitoring();
    this.startCacheCleanup();
  }

  // Performance monitoring
  private initializePerformanceMonitoring(): void {
    // Monitor memory usage
    if ('memory' in performance) {
      timer(0, 5000).subscribe(() => {
        const memory = (performance as any).memory;
        this.updateMetric('memoryUsage', memory.usedJSHeapSize);
      });
    }

    // Monitor network performance
    this.monitorNetworkPerformance();

    // Monitor render performance
    this.monitorRenderPerformance();
  }

  private monitorNetworkPerformance(): void {
    // Observer les requêtes réseau
    const originalFetch = window.fetch;
    window.fetch = async (...args) => {
      const start = performance.now();
      try {
        const response = await originalFetch(...args);
        const end = performance.now();
        this.updateMetric('apiResponseTime', end - start);
        return response;
      } catch (error) {
        const end = performance.now();
        this.updateMetric('apiResponseTime', end - start);
        this.incrementErrorRate();
        throw error;
      }
    };
  }

  private monitorRenderPerformance(): void {
    // Observer les changements de DOM
    const observer = new MutationObserver(() => {
      const start = performance.now();
      requestAnimationFrame(() => {
        const end = performance.now();
        this.updateMetric('renderTime', end - start);
      });
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true
    });
  }

  // Cache management
  set<T>(key: string, data: T, ttl: number = this.defaultTTL): void {
    // Nettoyer le cache si nécessaire
    if (this.cache.size >= this.maxCacheSize) {
      this.cleanupCache();
    }

    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      ttl,
      hits: 0
    });
  }

  get<T>(key: string): T | null {
    const item = this.cache.get(key);
    
    if (!item) {
      return null;
    }

    // Vérifier si l'item est expiré
    if (Date.now() - item.timestamp > item.ttl) {
      this.cache.delete(key);
      return null;
    }

    // Incrémenter les hits
    item.hits++;
    return item.data;
  }

  delete(key: string): boolean {
    return this.cache.delete(key);
  }

  clear(): void {
    this.cache.clear();
  }

  private cleanupCache(): void {
    const now = Date.now();
    const items = Array.from(this.cache.entries());

    // Supprimer les items expirés
    items.forEach(([key, item]) => {
      if (now - item.timestamp > item.ttl) {
        this.cache.delete(key);
      }
    });

    // Si toujours trop d'items, supprimer les moins utilisés
    if (this.cache.size >= this.maxCacheSize) {
      const sortedItems = items
        .sort((a, b) => a[1].hits - b[1].hits)
        .slice(0, Math.floor(this.maxCacheSize * 0.8));

      sortedItems.forEach(([key]) => this.cache.delete(key));
    }
  }

  private startCacheCleanup(): void {
    timer(60000, 60000).subscribe(() => {
      this.cleanupCache();
      this.updateMetric('cacheSize', this.cache.size);
    });
  }

  // Performance metrics
  get performanceMetrics$(): Observable<PerformanceMetrics> {
    return this._performanceMetrics$.asObservable();
  }

  private updateMetric(key: keyof PerformanceMetrics, value: number): void {
    const current = this._performanceMetrics$.value;
    this._performanceMetrics$.next({
      ...current,
      [key]: value
    });
  }

  private incrementErrorRate(): void {
    const current = this._performanceMetrics$.value;
    this._performanceMetrics$.next({
      ...current,
      errorRate: current.errorRate + 1
    });
  }

  // Lazy loading utilities
  lazyLoad<T>(
    loader: () => Promise<T>,
    key: string,
    ttl: number = this.defaultTTL
  ): Promise<T> {
    // Vérifier le cache d'abord
    const cached = this.get<T>(key);
    if (cached) {
      return Promise.resolve(cached);
    }

    // Charger les données
    return loader().then(data => {
      this.set(key, data, ttl);
      return data;
    });
  }

  // Debounced utility
  debounce<T>(fn: () => T, delay: number = 300): Observable<T> {
    return fromEvent(document, 'input').pipe(
      debounceTime(delay),
      distinctUntilChanged(),
      map(() => fn()),
      startWith(fn())
    );
  }

  // Performance optimization utilities
  throttle<T>(fn: () => T, limit: number = 100): () => T {
    let inThrottle = false;
    return () => {
      if (!inThrottle) {
        inThrottle = true;
        const result = fn();
        setTimeout(() => inThrottle = false, limit);
        return result;
      }
      return fn();
    };
  }

  // Memory optimization
  optimizeMemory(): void {
    // Forcer le garbage collection si disponible
    if ('gc' in window) {
      (window as any).gc();
    }

    // Nettoyer le cache
    this.cleanupCache();

    // Nettoyer les event listeners inutilisés
    this.cleanupEventListeners();
  }

  private cleanupEventListeners(): void {
    // Implémenter le nettoyage des event listeners
    // Ceci est un placeholder - l'implémentation réelle dépendrait de votre application
  }

  // Performance reporting
  getPerformanceReport(): PerformanceMetrics {
    return this._performanceMetrics$.value;
  }

  // Cache statistics
  getCacheStats(): {
    size: number;
    hitRate: number;
    memoryUsage: number;
  } {
    let totalHits = 0;
    let totalItems = 0;

    this.cache.forEach(item => {
      totalHits += item.hits;
      totalItems++;
    });

    const hitRate = totalItems > 0 ? totalHits / totalItems : 0;
    const memoryUsage = this.estimateMemoryUsage();

    return {
      size: this.cache.size,
      hitRate,
      memoryUsage
    };
  }

  private estimateMemoryUsage(): number {
    let totalSize = 0;
    
    this.cache.forEach(item => {
      try {
        totalSize += JSON.stringify(item.data).length * 2; // Approximation
      } catch (e) {
        // Ignorer les erreurs de sérialisation
      }
    });

    return totalSize;
  }

  // Performance warnings
  checkPerformanceIssues(): string[] {
    const issues: string[] = [];
    const metrics = this._performanceMetrics$.value;
    const cacheStats = this.getCacheStats();

    // Vérifier l'utilisation mémoire
    if (metrics.memoryUsage > 100 * 1024 * 1024) { // 100MB
      issues.push('Utilisation mémoire élevée (>100MB)');
    }

    // Vérifier le temps de réponse API
    if (metrics.apiResponseTime > 2000) { // 2 secondes
      issues.push('Temps de réponse API lent (>2s)');
    }

    // Vérifier le taux d'erreur
    if (metrics.errorRate > 5) {
      issues.push('Taux d\'erreur élevé (>5%)');
    }

    // Vérifier la taille du cache
    if (cacheStats.size > this.maxCacheSize * 0.9) {
      issues.push('Cache presque plein');
    }

    // Vérifier le hit rate du cache
    if (cacheStats.hitRate < 0.5) { // 50%
      issues.push('Hit rate du cache faible (<50%)');
    }

    return issues;
  }
}
